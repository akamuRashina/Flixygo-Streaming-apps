import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as winweb;

import '../models/api_models.dart';
import '../services/auth_service.dart';
import '../services/comment_service.dart';
import '../services/profile_photo_service.dart';
import '../services/stream_service.dart';
import '../services/watch_history_service.dart';
import '../theme/app_theme.dart';
import 'home_page.dart';
import 'login_page.dart';

/// Only Android and iOS have a real webview_flutter implementation.
bool get _platformSupportsMobileWebView {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

/// Windows gets its own embedded WebView2 pane (via the `webview_windows`
/// package) instead of falling back to "open in browser" — see
/// _openWindowsWebview below. Requires the Microsoft Edge WebView2 Runtime,
/// which ships in the box on Windows 11 and current Windows 10.
bool get _platformSupportsWindowsWebView {
  if (kIsWeb) return false;
  try {
    return Platform.isWindows;
  } catch (_) {
    return false;
  }
}

class VideoPlayerPage extends StatefulWidget {
  final MovieItem movie;

  /// Movies only — comes straight from the movie detail's `stream_url`.
  final String? directStreamUrl;

  /// Anime/K-Drama only — the episode currently playing.
  final String? episodeSlug;
  final int? episodeNumber;

  /// Anime/K-Drama only — full episode list (ascending), so the in-player
  /// controls can skip to the next episode without going back to the
  /// detail page.
  final List<EpisodeInfo> episodes;

  const VideoPlayerPage({
    super.key,
    required this.movie,
    this.directStreamUrl,
    this.episodeSlug,
    this.episodeNumber,
    this.episodes = const [],
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

bool _isMovie(ContentType t) => t == ContentType.movie;

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  final TextEditingController _commentController = TextEditingController();
  bool _isDescExpanded = false;
  late int _currentEpisode;
  String? _currentEpisodeSlug;

  // ── Native (media_kit) playback — used whenever a candidate URL turns
  // out to actually be playable media once we try it. ──
  Player? _player;
  VideoController? _videoController;
  bool _usesNativePlayer = false;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playingSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  // ── Embed-page fallback ──
  WebViewController? _webController; // Android / iOS
  winweb.WebviewController? _winWebController; // Windows (WebView2)
  StreamSubscription? _winBridgeSub;
  String? _externalPlayUrl; // macOS / Linux / web — open in system browser
  bool _externalPlayOpened = false;

  /// True once the JS bridge (see _bridgeScript) has found a real
  /// `<video>` element on the embed page and hooked into it, so our own
  /// transport controls can drive it directly instead of the site's own
  /// player UI.
  bool _embedVideoHooked = false;

  /// Whether the current playback (native OR a hooked embed `<video>`)
  /// can actually be driven by our transport controls.
  bool get _hasControllablePlayback => _usesNativePlayer || _embedVideoHooked;

  bool _loadingStream = true;
  String? _streamError;
  StreamData? _streamData;
  String? _selectedQuality;

  /// Bumped on every new load (episode change / quality switch) so that a
  /// slow probe from a previous attempt can't clobber newer state if it
  /// resolves late.
  int _loadGen = 0;

  // ── Custom controls overlay ──
  bool _controlsVisible = true;
  bool _isLocked = false;
  Timer? _hideControlsTimer;
  bool _isFullscreenActive = false;

  List<CommentItem> _comments = [];
  bool _commentsLoading = true;
  bool _sendingComment = false;

  String? _myUsername;
  String? _myPhotoUrl;

  Timer? _historyTicker;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episodeNumber ?? 1;
    _currentEpisodeSlug = widget.episodeSlug;

    _loadMyProfile();

    if (_isMovie(widget.movie.contentType)) {
      _loadMovieStream(widget.directStreamUrl);
    } else {
      _loadEpisodeStream(widget.episodeSlug);
    }
    _loadComments();
    _scheduleAutoHideControls();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _historyTicker?.cancel();
    _saveWatchHistory(); // best-effort final save
    _disposePlayer();
    _disposeEmbedControllers();
    _commentController.dispose();
    if (_isFullscreenActive) {
      _restoreSystemUI();
    }
    super.dispose();
  }

  Future<void> _loadMyProfile() async {
    _myUsername = await AuthService.instance.getUsername();
    _myPhotoUrl = await ProfilePhotoService.instance.getPhotoUrl();
    if (mounted) setState(() {});
  }

  // ──────────────────────────────────────────────
  //  STREAM LOADING
  //
  //  The rule (per source): try `stream_url` for real. If it actually
  //  plays, use it. If it doesn't, try `embed_url` the same way. If
  //  neither is a raw playable stream, load `embed_url` in an actual
  //  browser engine (WebView) instead of guessing from the URL string.
  // ──────────────────────────────────────────────

  Future<void> _loadMovieStream(String? url) async {
    await _resolveAndPlay(streamUrl: url, embedUrl: null);
  }

  Future<void> _loadEpisodeStream(String? episodeSlug) async {
    if (episodeSlug == null || episodeSlug.isEmpty) {
      ++_loadGen;
      _disposePlayer();
      _disposeEmbedControllers();
      setState(() {
        _loadingStream = false;
        _streamError = 'Episode tidak ditemukan.';
      });
      return;
    }

    setState(() {
      _loadingStream = true;
      _streamError = null;
    });

    try {
      final data = await StreamService.instance.getStream(
        type: widget.movie.contentType,
        episodeSlug: episodeSlug,
      );
      if (!mounted) return;
      setState(() {
        _streamData = data;
        _selectedQuality = data.qualities.isNotEmpty ? data.qualities.first.quality : null;
      });
      await _resolveAndPlay(streamUrl: data.streamUrl, embedUrl: data.embedUrl, qualities: data.qualities);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStream = false;
        _streamError = 'Gagal memuat video ($e).';
      });
    }
  }

  /// Tries every candidate URL as real, native playback (in priority
  /// order: stream_url, embed_url, then each quality's stream/embed
  /// URLs). Falls back to loading `embed_url` (or the first candidate)
  /// in a WebView only if nothing played natively.
  Future<void> _resolveAndPlay({
    required String? streamUrl,
    required String? embedUrl,
    List<StreamQuality> qualities = const [],
  }) async {
    final gen = ++_loadGen;
    _disposePlayer();
    _disposeEmbedControllers();
    setState(() {
      _loadingStream = true;
      _streamError = null;
      _usesNativePlayer = false;
    });

    final attempts = <String>[
      if (streamUrl != null && streamUrl.isNotEmpty) streamUrl,
      if (embedUrl != null && embedUrl.isNotEmpty) embedUrl,
      for (final q in qualities) ...[
        if (q.streamUrl != null && q.streamUrl!.isNotEmpty) q.streamUrl!,
        if (q.embedUrl != null && q.embedUrl!.isNotEmpty) q.embedUrl!,
      ],
    ];

    if (attempts.isEmpty) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _loadingStream = false;
        _streamError =
            'Belum ada video untuk judul ini di server. Ini bukan masalah aplikasi — sumber videonya memang belum tersedia.';
      });
      return;
    }

    for (final url in attempts) {
      final played = await _tryNativeOpen(url, gen);
      if (gen != _loadGen) return; // a newer load started while we probed
      if (played) {
        _startHistoryTicker();
        return;
      }
    }

    // Nothing was directly playable — load the embed page for real in a
    // browser engine instead of trying to guess.
    final embedTarget = (embedUrl != null && embedUrl.isNotEmpty) ? embedUrl : attempts.first;
    await _openEmbedFallback(embedTarget, gen);
  }

  /// Actually attempts to play [url] with media_kit and waits (with a
  /// timeout) to see whether it's really a playable stream, rather than
  /// guessing from the URL's shape. Returns true and commits the player
  /// on success; disposes the probe and returns false on failure.
  Future<bool> _tryNativeOpen(String url, int generation) async {
    final player = Player();
    final controller = VideoController(player);
    final completer = Completer<bool>();
    StreamSubscription<String>? errorSub;
    StreamSubscription<Duration>? durationSub;
    StreamSubscription<int?>? widthSub;
    Timer? timeoutTimer;

    void finish(bool ok) {
      if (!completer.isCompleted) completer.complete(ok);
    }

    errorSub = player.stream.error.listen((_) => finish(false));
    durationSub = player.stream.duration.listen((d) {
      if (d > Duration.zero) finish(true);
    });
    // Some HLS playlists (e.g. kdrama .m3u8 sources) don't report a total
    // duration right away, or ever, but do start decoding real frames —
    // catch that case too instead of only waiting on duration.
    widthSub = player.stream.width.listen((w) {
      if (w != null && w > 0) finish(true);
    });
    // 12s gives slower CDNs (and HLS playlists that take a moment to
    // fetch/parse) enough room; bump this further if needed.
    timeoutTimer = Timer(const Duration(seconds: 12), () => finish(false));

    // Many aggregator/CDN sources (dracma/desustream-style hosts) reject
    // requests that don't look like they came from a browser tab on their
    // own site — no Referer/User-Agent, and mpv's default UA, both get
    // blocked with a 403. Send a normal desktop-browser UA and a Referer
    // matching the URL's own host, which satisfies most anti-hotlink
    // checks without needing to know the real embedding page.
    final headers = <String, String>{
      'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    };
    final host = Uri.tryParse(url)?.host;
    if (host != null && host.isNotEmpty) {
      headers['referer'] = 'https://$host/';
      headers['origin'] = 'https://$host';
    }

    bool success;
    try {
      await player.open(Media(url, httpHeaders: headers));
      success = await completer.future;
    } catch (_) {
      success = false;
    }

    timeoutTimer.cancel();
    await errorSub.cancel();
    await durationSub.cancel();
    await widthSub.cancel();

    if (generation != _loadGen || !mounted) {
      await player.dispose();
      return false;
    }

    if (!success) {
      await player.dispose();
      return false;
    }

    _disposePlayer(); // clear out whatever was previously committed
    _player = player;
    _videoController = controller;
    _attachPlayerListeners();
    setState(() {
      _usesNativePlayer = true;
      _loadingStream = false;
      _streamError = null;
    });
    return true;
  }

  Future<void> _openEmbedFallback(String url, int generation) async {
    _disposeEmbedControllers();

    if (_platformSupportsMobileWebView) {
      late final WebViewController controller;
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..addJavaScriptChannel(
          'FlixyGoBridge',
          onMessageReceived: (message) => _handleBridgeMessage(message.message),
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (generation != _loadGen) return;
              controller.runJavaScript(
                _bridgeScript('FlixyGoBridge.postMessage(JSON.stringify(payload));'),
              );
            },
          ),
        )
        ..loadRequest(Uri.parse(url));
      if (!mounted || generation != _loadGen) return;
      setState(() {
        _webController = controller;
        _embedVideoHooked = false;
        _loadingStream = false;
      });
    } else if (_platformSupportsWindowsWebView) {
      try {
        final controller = winweb.WebviewController();
        await controller.initialize();
        await controller.setBackgroundColor(Colors.black);
        await controller.setPopupWindowPolicy(winweb.WebviewPopupWindowPolicy.deny);
        // Registers the hook script to auto-run on every document this
        // webview loads (including redirects), rather than a one-shot
        // injection after a single page-load event.
        await controller.addScriptToExecuteOnDocumentCreated(
          _bridgeScript('window.chrome.webview.postMessage(JSON.stringify(payload));'),
        );
        _winBridgeSub = controller.webMessage.listen((message) {
          final text = message is String ? message : jsonEncode(message);
          _handleBridgeMessage(text);
        });
        await controller.loadUrl(url);
        if (!mounted || generation != _loadGen) {
          await controller.dispose();
          return;
        }
        setState(() {
          _winWebController = controller;
          _embedVideoHooked = false;
          _loadingStream = false;
        });
      } catch (e) {
        if (!mounted || generation != _loadGen) return;
        setState(() {
          _loadingStream = false;
          _streamError =
              'Gagal memuat WebView2 di Windows ($e). Pastikan Microsoft Edge WebView2 Runtime terpasang di komputer ini.';
        });
        return;
      }
    } else {
      if (!mounted || generation != _loadGen) return;
      setState(() {
        _externalPlayUrl = url;
        _loadingStream = false;
      });
    }
    _startHistoryTicker();
  }

  /// JS injected into the embed page. It polls for a plain `<video>`
  /// element (including inside same-origin iframes), disables the site's
  /// native `controls` bar, force-stretches it to fill the screen (many
  /// embed pages lay the video out at a small fixed size meant for their
  /// own page, not full-bleed), and forwards play/pause/time/duration/
  /// ended events back to Flutter as JSON — letting our own transport
  /// controls drive the real element instead of the site's own player UI.
  /// [postExpr] is the platform-specific call that actually delivers
  /// `payload` back to Dart.
  ///
  /// Many aggregator pages plant a short, muted ad/preview clip before the
  /// real content — sometimes as a separate `<video>`, sometimes by
  /// swapping the *same* `<video>` element's source once the ad finishes.
  /// So instead of a one-shot "found it" decision, every `<video>` we see
  /// keeps being watched: real episodes/movies are essentially never
  /// under a minute, so a known duration under that just means "not it
  /// yet" rather than "never" — we keep re-checking as duration changes,
  /// and hand control back (`unhook`) if a previously-real video swaps
  /// back to something short. Scanning itself never stops, so a brand
  /// new `<video>` node inserted after an ad also gets picked up.
  ///
  /// Limitation: cross-origin iframes are blocked from script access by
  /// the browser itself (not something we can bypass) — if a site nests
  /// its actual player inside a cross-origin iframe, we can't reach it
  /// and playback falls back to the site's own on-page controls.
  String _bridgeScript(String postExpr) {
    return '''
(function() {
  function post(payload) { $postExpr }
  var hookedVideo = null;

  function forceFullBleed(video) {
    try {
      video.style.setProperty('position', 'fixed', 'important');
      video.style.setProperty('top', '0', 'important');
      video.style.setProperty('left', '0', 'important');
      video.style.setProperty('width', '100vw', 'important');
      video.style.setProperty('height', '100vh', 'important');
      video.style.setProperty('max-width', 'none', 'important');
      video.style.setProperty('max-height', 'none', 'important');
      video.style.setProperty('object-fit', 'contain', 'important');
      video.style.setProperty('background', '#000', 'important');
      video.style.setProperty('z-index', '2147483647', 'important');
      if (document.documentElement) {
        document.documentElement.style.setProperty('background', '#000', 'important');
      }
      if (document.body) {
        document.body.style.setProperty('margin', '0', 'important');
        document.body.style.setProperty('padding', '0', 'important');
        document.body.style.setProperty('overflow', 'hidden', 'important');
        document.body.style.setProperty('background', '#000', 'important');
      }
      var parent = video.parentElement;
      for (var i = 0; i < 3 && parent; i++) {
        parent.style.setProperty('width', '100%', 'important');
        parent.style.setProperty('height', '100%', 'important');
        parent.style.setProperty('max-width', 'none', 'important');
        parent.style.setProperty('max-height', 'none', 'important');
        parent = parent.parentElement;
      }
    } catch (e) {}
  }

  function setHooked(video) {
    if (hookedVideo === video) return;
    hookedVideo = video;
    window.__flixygoActiveVideo = video;
    try { video.controls = false; } catch (e) {}
    forceFullBleed(video);
    post({type:'ready', duration: video.duration || 0, paused: video.paused});
  }

  function clearHooked(video) {
    if (hookedVideo === video) {
      hookedVideo = null;
      window.__flixygoActiveVideo = null;
      post({type:'unhook'});
    }
  }

  // Real episodes/movies are essentially never under a minute long.
  // A short *known* duration means "this is probably an ad, not it yet"
  // rather than a permanent verdict — re-run this any time the element's
  // duration actually changes (ad-insertion libraries commonly swap the
  // source on the same <video> tag once the ad finishes).
  function reconsider(video) {
    var d = video.duration;
    var known = isFinite(d) && d > 0;
    if (known && d >= 60) {
      setHooked(video);
    } else if (hookedVideo === video) {
      clearHooked(video);
    }
  }

  function watch(video) {
    if (video.__flixygoWatched) { reconsider(video); return; }
    video.__flixygoWatched = true;
    video.addEventListener('loadedmetadata', function() { reconsider(video); forceFullBleed(video); });
    video.addEventListener('durationchange', function() { reconsider(video); });
    video.addEventListener('emptied', function() { reconsider(video); });
    video.addEventListener('play', function() { if (hookedVideo === video) post({type:'play'}); });
    video.addEventListener('pause', function() { if (hookedVideo === video) post({type:'pause'}); });
    video.addEventListener('timeupdate', function() {
      if (hookedVideo === video) {
        post({type:'time', currentTime: video.currentTime, duration: video.duration || 0});
      }
    });
    video.addEventListener('ended', function() { if (hookedVideo === video) post({type:'ended'}); });
    reconsider(video);
  }

  function scan() {
    var candidates = Array.prototype.slice.call(document.querySelectorAll('video'));
    // Best-effort: same-origin nested iframes only. Cross-origin frames
    // throw when touched and are silently skipped — the browser itself
    // blocks that, there's no way around it from injected script.
    var frames = document.querySelectorAll('iframe');
    for (var i = 0; i < frames.length; i++) {
      try {
        var doc = frames[i].contentDocument;
        if (doc) candidates = candidates.concat(Array.prototype.slice.call(doc.querySelectorAll('video')));
      } catch (e) {}
    }
    for (var j = 0; j < candidates.length; j++) { watch(candidates[j]); }
  }

  var tries = 0;
  var announcedNoVideo = false;
  var timer = setInterval(function() {
    tries++;
    scan();
    if (!hookedVideo && !announcedNoVideo && tries > 40) {
      announcedNoVideo = true;
      post({type:'novideo'});
    }
    // Scanning keeps running (cheap, page-scoped) so a video inserted
    // later — after an ad finishes, or a "click to play" gate — still
    // gets picked up even after the initial timeout announcement.
  }, 500);
})();
''';
  }

  void _handleBridgeMessage(String raw) {
    if (!mounted || _usesNativePlayer) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (data['type'] as String?) {
      case 'ready':
        final d = (data['duration'] as num?)?.toDouble() ?? 0;
        setState(() {
          _embedVideoHooked = true;
          _isPlaying = data['paused'] == false;
          if (d > 0) _duration = Duration(milliseconds: (d * 1000).round());
        });
        break;
      case 'play':
        setState(() => _isPlaying = true);
        break;
      case 'pause':
      case 'ended':
        setState(() => _isPlaying = false);
        break;
      case 'time':
        final cur = (data['currentTime'] as num?)?.toDouble() ?? 0;
        final dur = (data['duration'] as num?)?.toDouble() ?? 0;
        setState(() {
          _position = Duration(milliseconds: (cur * 1000).round());
          if (dur > 0) _duration = Duration(milliseconds: (dur * 1000).round());
        });
        break;
      case 'duration':
        final dur = (data['duration'] as num?)?.toDouble() ?? 0;
        if (dur > 0) setState(() => _duration = Duration(milliseconds: (dur * 1000).round()));
        break;
      case 'novideo':
        // Couldn't find a plain <video> element (often a nested
        // cross-origin iframe player) — leave the site's own controls
        // as the only way to interact with this particular source.
        break;
      case 'unhook':
        // The video we'd taken over swapped back to something short
        // (e.g. site returned to an ad) — hand control back to the
        // site's own UI until a real video is found again.
        setState(() {
          _embedVideoHooked = false;
          _isPlaying = false;
        });
        break;
    }
  }

  Future<void> _embedRunScript(String script) async {
    if (_webController != null) {
      await _webController!.runJavaScript(script);
    } else if (_winWebController != null) {
      await _winWebController!.executeScript(script);
    }
  }

  Future<void> _embedTogglePlayPause() {
    return _embedRunScript(
      _isPlaying
          ? "(function(){var v=window.__flixygoActiveVideo; if(v) v.pause();})();"
          : "(function(){var v=window.__flixygoActiveVideo; if(v) v.play();})();",
    );
  }

  Future<void> _embedSeekRelative(Duration delta) {
    final targetSeconds = (_position + delta).inMilliseconds / 1000.0;
    return _embedRunScript(
      "(function(){var v=window.__flixygoActiveVideo; if(v) v.currentTime=Math.max(0,$targetSeconds);})();",
    );
  }

  Future<void> _embedSeekTo(Duration position) {
    final seconds = position.inMilliseconds / 1000.0;
    return _embedRunScript(
      "(function(){var v=window.__flixygoActiveVideo; if(v) v.currentTime=$seconds;})();",
    );
  }

  void _attachPlayerListeners() {
    _positionSub = _player!.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = _player!.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _playingSub = _player!.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
  }

  void _disposePlayer() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _player?.dispose();
    _player = null;
    _videoController = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = false;
  }

  void _disposeEmbedControllers() {
    _webController = null;
    _winBridgeSub?.cancel();
    _winBridgeSub = null;
    _winWebController?.dispose();
    _winWebController = null;
    _externalPlayUrl = null;
    _externalPlayOpened = false;
    _embedVideoHooked = false;
  }

  Future<void> _openExternalPlayer() async {
    final url = _externalPlayUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (opened) {
      setState(() => _externalPlayOpened = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak bisa membuka browser.', style: GoogleFonts.poppins())),
      );
    }
  }

  // ──────────────────────────────────────────────
  //  QUALITY SWITCHING (from the `qualities` jsonb column)
  // ──────────────────────────────────────────────

  Future<void> _switchQuality(StreamQuality quality) async {
    if (quality.quality == _selectedQuality) return;
    final resumeAt = _usesNativePlayer ? _position : Duration.zero;

    await _resolveAndPlay(streamUrl: quality.streamUrl, embedUrl: quality.embedUrl);
    if (!mounted) return;

    setState(() => _selectedQuality = quality.quality);

    if (_usesNativePlayer && resumeAt > Duration.zero) {
      await _player?.seek(resumeAt);
    }
  }

  void _showQualitySheet() {
    final qualities = _streamData?.qualities ?? const <StreamQuality>[];
    if (qualities.isEmpty) return;
    _hideControlsTimer?.cancel();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A2018), Color(0xFF1A1209)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            Text('Kualitas Video', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            ...qualities.map((q) {
              final selected = q.quality == _selectedQuality;
              final label = q.server.isNotEmpty ? '${q.quality} · ${q.server}' : q.quality;
              return ListTile(
                title: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: selected ? const Icon(Icons.check_circle_rounded, color: Color(0xFFDE903A)) : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _switchQuality(q);
                },
              );
            }),
          ],
        ),
      ),
    ).whenComplete(() => _scheduleAutoHideControls());
  }

  // ──────────────────────────────────────────────
  //  WATCH HISTORY
  // ──────────────────────────────────────────────

  void _startHistoryTicker() {
    _historyTicker?.cancel();
    _elapsedSeconds = 0;
    _historyTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _elapsedSeconds++;
      if (_elapsedSeconds % 15 == 0) {
        _saveWatchHistory();
      }
    });
  }

  Future<void> _saveWatchHistory() async {
    if (!await AuthService.instance.isLoggedIn()) return;
    if (widget.movie.slug.isEmpty) return;
    try {
      final duration = _hasControllablePlayback ? _position.inSeconds : _elapsedSeconds;
      await WatchHistoryService.instance.update(
        contentType: contentTypeToApi(widget.movie.contentType),
        contentSlug: widget.movie.slug,
        episodeSlug: _currentEpisodeSlug,
        lastDurationSeconds: duration,
      );
    } catch (_) {
      // Non-fatal — history sync failures shouldn't interrupt playback.
    }
  }

  // ──────────────────────────────────────────────
  //  COMMENTS
  // ──────────────────────────────────────────────

  Future<void> _loadComments() async {
    if (widget.movie.slug.isEmpty) {
      setState(() => _commentsLoading = false);
      return;
    }
    setState(() => _commentsLoading = true);
    try {
      final comments = await CommentService.instance.list(
        contentType: contentTypeToApi(widget.movie.contentType),
        contentSlug: widget.movie.slug,
        episodeSlug: _currentEpisodeSlug,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _commentsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;

    if (!await AuthService.instance.isLoggedIn()) {
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      if (!await AuthService.instance.isLoggedIn()) return;
      await _loadMyProfile();
    }

    setState(() => _sendingComment = true);
    try {
      await CommentService.instance.add(
        contentType: contentTypeToApi(widget.movie.contentType),
        contentSlug: widget.movie.slug,
        episodeSlug: _currentEpisodeSlug,
        commentText: text,
      );
      _commentController.clear();
      await _loadComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim komentar', style: GoogleFonts.poppins())),
      );
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  // ──────────────────────────────────────────────
  //  EPISODES
  // ──────────────────────────────────────────────

  /// `widget.episodes` isn't guaranteed to already be in ascending order
  /// by the time it gets here — sort defensively so the chip row always
  /// reads 1, 2, 3, ... and "skip to next episode" always goes forward.
  List<EpisodeInfo> get _sortedEpisodes {
    final list = List<EpisodeInfo>.from(widget.episodes);
    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  EpisodeInfo? _nextEpisode() {
    final episodes = _sortedEpisodes;
    if (episodes.isEmpty) return null;
    final idx = episodes.indexWhere((e) => e.slug == _currentEpisodeSlug);
    if (idx == -1 || idx + 1 >= episodes.length) return null;
    return episodes[idx + 1];
  }

  void _changeEpisode(EpisodeInfo episode) {
    if (episode.slug == _currentEpisodeSlug) return;
    _historyTicker?.cancel();
    _saveWatchHistory();
    setState(() {
      _currentEpisode = episode.number;
      _currentEpisodeSlug = episode.slug;
    });
    _loadEpisodeStream(episode.slug);
    _loadComments();
  }

  // ──────────────────────────────────────────────
  //  CONTROLS: visibility / lock / transport / fullscreen
  // ──────────────────────────────────────────────

  void _scheduleAutoHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isLocked) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleAutoHideControls();
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      _controlsVisible = true;
    });
    if (!_isLocked) _scheduleAutoHideControls();
  }

  void _togglePlayPause() {
    if (_usesNativePlayer) {
      _player?.playOrPause();
    } else if (_embedVideoHooked) {
      _embedTogglePlayPause();
      setState(() => _isPlaying = !_isPlaying); // optimistic; JS event corrects it
    }
    _scheduleAutoHideControls();
  }

  void _seekRelative(Duration delta) {
    if (_usesNativePlayer) {
      if (_player == null) return;
      final target = _position + delta;
      final clamped = target < Duration.zero
          ? Duration.zero
          : (_duration > Duration.zero && target > _duration ? _duration : target);
      _player!.seek(clamped);
    } else if (_embedVideoHooked) {
      _embedSeekRelative(delta);
    }
    _scheduleAutoHideControls();
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreenActive) {
      await _exitFullscreen();
    } else {
      await _enterFullscreen();
    }
  }

  Future<void> _enterFullscreen() async {
    try {
      await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      );
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {
      // Desktop platforms may not support forced orientation/immersive
      // mode — the video area still expands to fill the page below.
    }
    if (!mounted) return;
    setState(() {
      _isFullscreenActive = true;
      _controlsVisible = true;
    });
    _scheduleAutoHideControls();
  }

  Future<void> _exitFullscreen() async {
    await _restoreSystemUI();
    if (!mounted) return;
    setState(() {
      _isFullscreenActive = false;
      _controlsVisible = true;
    });
    _scheduleAutoHideControls();
  }

  Future<void> _restoreSystemUI() async {
    try {
      await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
      );
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    } catch (_) {}
  }

  // ──────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isFullscreenActive) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          _exitFullscreen();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: _buildVideoStage(
              height: MediaQuery.of(context).size.height,
              isFullscreen: true,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.homeBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.movie.title,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          _buildVideoStage(height: 240, isFullscreen: false),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.episodes.isNotEmpty) _buildEpisodeSection(),
                  _buildDescriptionSection(),
                  _buildCommentSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── VIDEO STAGE (player surface + controls overlay) ──
  Widget _buildVideoStage({required double height, required bool isFullscreen}) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Container(
        color: Colors.black,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _isLocked ? null : _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                // Block the underlying surface once we're locked, or once
                // we've hooked the embed page's own <video> element — at
                // that point our controls are the only thing that should
                // drive playback, not the site's own play button.
                ignoring: _isLocked || _embedVideoHooked,
                child: _buildPlayerSurface(),
              ),
              _buildControlsOverlay(isFullscreen: isFullscreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerSurface() {
    if (_loadingStream) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFDE903A)));
    }

    if (_streamError != null) {
      return _buildErrorState();
    }

    if (_usesNativePlayer) {
      if (_videoController == null) return const SizedBox.shrink();
      return Video(controller: _videoController!, controls: NoVideoControls, fit: BoxFit.contain);
    }

    if (_webController != null) {
      return WebViewWidget(controller: _webController!);
    }

    if (_winWebController != null) {
      return winweb.Webview(_winWebController!);
    }

    if (_externalPlayUrl != null) {
      return _buildExternalPlayPrompt();
    }

    return const SizedBox.shrink();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 40),
            const SizedBox(height: 12),
            Text(
              _streamError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                if (_isMovie(widget.movie.contentType)) {
                  _loadMovieStream(widget.directStreamUrl);
                } else {
                  _loadEpisodeStream(_currentEpisodeSlug);
                }
              },
              child: Text('Coba lagi', style: GoogleFonts.poppins(color: const Color(0xFFDE903A), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalPlayPrompt() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _externalPlayOpened ? Icons.open_in_new_rounded : Icons.play_circle_outline_rounded,
              color: const Color(0xFFDE903A),
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              'Pemutar video ini dibuka lewat browser di perangkat ini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openExternalPlayer,
              icon: const Icon(Icons.open_in_browser_rounded, size: 18),
              label: Text(
                _externalPlayOpened ? 'Buka Lagi di Browser' : 'Buka Player di Browser',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDE903A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CONTROLS OVERLAY ──
  Widget _buildControlsOverlay({required bool isFullscreen}) {
    if (_loadingStream || _streamError != null) return const SizedBox.shrink();

    if (_isLocked) {
      return Positioned(
        top: 14,
        right: 14,
        child: _buildLockButton(),
      );
    }

    return AnimatedOpacity(
      opacity: _controlsVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.55),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.6),
              ],
              stops: const [0.0, 0.25, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTitleBlock()),
                    _buildLockButton(),
                  ],
                ),
              ),
              if (_hasControllablePlayback) Center(child: _buildCenterTransportControls()),
              if (_hasControllablePlayback)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  child: _buildBottomBar(isFullscreen: isFullscreen),
                )
              else
                Positioned(
                  right: 12,
                  bottom: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildQualityButton(),
                      const SizedBox(width: 4),
                      _buildFullscreenButton(isFullscreen: isFullscreen),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBlock() {
    final episodeLabel = !_isMovie(widget.movie.contentType) ? 'Episode $_currentEpisode' : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.movie.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        if (episodeLabel != null) ...[
          const SizedBox(height: 2),
          Text(episodeLabel, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70)),
        ],
      ],
    );
  }

  Widget _buildLockButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _toggleLock,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.4),
          ),
          child: Icon(
            _isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterTransportControls() {
    final hasNextEpisode = _nextEpisode() != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _transportButton(icon: Icons.fast_rewind_rounded, onTap: () => _seekRelative(const Duration(seconds: -10))),
        const SizedBox(width: 20),
        _playPauseButton(),
        const SizedBox(width: 20),
        _transportButton(icon: Icons.fast_forward_rounded, onTap: () => _seekRelative(const Duration(seconds: 10))),
        const SizedBox(width: 20),
        _transportButton(
          icon: Icons.skip_next_rounded,
          onTap: hasNextEpisode ? () => _changeEpisode(_nextEpisode()!) : null,
          disabled: !hasNextEpisode,
        ),
      ],
    );
  }

  Widget _transportButton({required IconData icon, VoidCallback? onTap, bool disabled = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: disabled ? Colors.white24 : Colors.white, size: 34),
        ),
      ),
    );
  }

  Widget _playPauseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _togglePlayPause,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.6)),
          child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _buildBottomBar({required bool isFullscreen}) {
    final posText = _formatDuration(_position);
    final durText = _formatDuration(_duration);
    final maxMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final curMs = _position.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: const Color(0xFFDE903A),
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: const Color(0xFFDE903A),
          ),
          child: Slider(
            min: 0,
            max: maxMs,
            value: curMs,
            onChangeStart: (_) => _hideControlsTimer?.cancel(),
            onChanged: (v) => setState(() => _position = Duration(milliseconds: v.toInt())),
            onChangeEnd: (v) {
              final target = Duration(milliseconds: v.toInt());
              if (_usesNativePlayer) {
                _player?.seek(target);
              } else if (_embedVideoHooked) {
                _embedSeekTo(target);
              }
              _scheduleAutoHideControls();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$posText/$durText', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.white)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQualityButton(),
                  const SizedBox(width: 6),
                  _buildFullscreenButton(isFullscreen: isFullscreen),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQualityButton() {
    final qualities = _streamData?.qualities ?? const <StreamQuality>[];
    if (qualities.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _showQualitySheet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hd_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 2),
              Text(
                _selectedQuality ?? 'Auto',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenButton({required bool isFullscreen}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _toggleFullscreen,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return '00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
  }

  // ──────────────────────────────────────────────
  //  BELOW-THE-FOLD SECTIONS (episodes / description / comments)
  // ──────────────────────────────────────────────

  Widget _buildEpisodeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: AppColors.homeBg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Episode', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _sortedEpisodes.map((ep) {
                final isSelected = ep.slug == _currentEpisodeSlug;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _changeEpisode(ep),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFDE903A) : const Color(0xFF2A2018),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFDE903A) : Colors.white.withOpacity(0.15),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${ep.number}',
                          style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Episode $_currentEpisode',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final String description = widget.movie.overview.isNotEmpty ? widget.movie.overview : 'Sinopsis belum tersedia.';
    final String displayText = _isDescExpanded
        ? description
        : (description.length > 200 ? '${description.substring(0, 200)}...' : description);

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.homeBg,
      child: GestureDetector(
        onTap: () => setState(() => _isDescExpanded = !_isDescExpanded),
        child: RichText(
          text: TextSpan(
            text: displayText,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white.withOpacity(0.8), height: 1.5),
            children: [
              if (!_isDescExpanded && description.length > 200)
                TextSpan(
                  text: ' Selengkapnya',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFDA8C35)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      color: AppColors.homeBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatarCircle(photoUrl: _myPhotoUrl, fallbackLetter: _myUsername),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2018),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                  ),
                  child: TextField(
                    controller: _commentController,
                    enabled: !_sendingComment,
                    onSubmitted: (_) => _sendComment(),
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tambahkan komentar...',
                      hintStyle: GoogleFonts.poppins(color: Colors.white.withOpacity(0.5), fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _sendComment,
                child: _sendingComment
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDE903A)))
                    : const Icon(Icons.send_rounded, color: Color(0xFFDE903A), size: 28),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${_comments.length} Komentar',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 16),
          if (_commentsLoading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white70)))
          else if (_comments.isEmpty)
            Text('Belum ada komentar. Jadilah yang pertama!', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _buildCommentItem(_comments[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommentItem comment) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatarCircle(photoUrl: comment.avatarUrl, fallbackLetter: comment.username),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(comment.username, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                comment.commentText,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white.withOpacity(0.8), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarCircle({String? photoUrl, String? fallbackLetter}) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(radius: 20, backgroundImage: NetworkImage(photoUrl));
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFDE903A),
      child: Text(
        (fallbackLetter != null && fallbackLetter.isNotEmpty) ? fallbackLetter[0].toUpperCase() : '?',
        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
