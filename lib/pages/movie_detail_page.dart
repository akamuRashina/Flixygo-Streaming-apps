import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/api_models.dart';
import '../services/content_service.dart';
import '../services/bookmark_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import 'home_page.dart';
import 'video_player_page.dart';
import 'login_page.dart';

class MovieDetailPage extends StatefulWidget {
  final MovieItem movie;

  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  bool _isSaved = false;
  bool _bookmarkBusy = false;

  ContentDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadBookmarkStatus();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await ContentService.instance.getDetail(
        type: ContentType.movie,
        slug: widget.movie.slug,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadBookmarkStatus() async {
    if (!await AuthService.instance.isLoggedIn()) return;
    try {
      final bookmarks = await BookmarkService.instance.list();
      if (!mounted) return;
      final saved = bookmarks.any((b) => b.slug == widget.movie.slug && b.type == 'movie');
      setState(() => _isSaved = saved);
    } catch (_) {
      // Non-fatal — leave as unsaved if the bookmark list fails to load.
    }
  }

  Future<void> _toggleSave() async {
    if (!await AuthService.instance.isLoggedIn()) {
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      if (!await AuthService.instance.isLoggedIn()) return;
    }
    if (_bookmarkBusy) return;

    setState(() => _bookmarkBusy = true);
    final wasSaved = _isSaved;
    try {
      if (wasSaved) {
        await BookmarkService.instance.remove(contentType: 'movie', contentSlug: widget.movie.slug);
      } else {
        await BookmarkService.instance.add(contentType: 'movie', contentSlug: widget.movie.slug);
      }
      if (!mounted) return;
      setState(() {
        _isSaved = !wasSaved;
        _bookmarkBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSaved ? '${widget.movie.title} disimpan ke favorit' : '${widget.movie.title} dihapus dari favorit',
            style: GoogleFonts.poppins(),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2A1C10),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _bookmarkBusy = false);
      final message = e is ApiException ? e.message : 'Gagal memperbarui favorit';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, style: GoogleFonts.poppins()), backgroundColor: const Color(0xFF8B2E2E)),
      );
    }
  }

  void _play() {
    final streamUrl = _detail?.streamUrl;
    if (streamUrl == null || streamUrl.isEmpty) {
      final message = (_detail?.unavailable ?? false)
          ? 'Film ini belum tersedia dari server sumber. Coba lagi nanti.'
          : 'Video belum tersedia untuk judul ini.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFF8B2E2E),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          movie: widget.movie.copyWith(overview: _detail?.synopsis, genres: _detail?.genres),
          directStreamUrl: streamUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0B07),
      body: Column(
        children: [
          Stack(
            children: [
              SizedBox(
                height: 380,
                width: double.infinity,
                child: Image.network(
                  (_detail?.poster.isNotEmpty ?? false) ? _detail!.poster : movie.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: movie.fallbackGradient,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.movie_creation_outlined, color: Colors.white38, size: 60),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                        const Color(0xFF0F0B07).withOpacity(0.95),
                        const Color(0xFF0F0B07),
                      ],
                      stops: const [0.0, 0.25, 0.55, 0.85, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 20,
                right: 20,
                child: Text(
                  (_detail?.title.isNotEmpty ?? false) ? _detail!.title : movie.title,
                  style: GoogleFonts.poppins(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFDE903A)))
                : _error != null && _detail == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 44),
                              const SizedBox(height: 14),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadDetail,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDE903A),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('Coba lagi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 10,
                                children: (_detail?.genres.isNotEmpty ?? false)
                                    ? _detail!.genres.map(_genreChip).toList()
                                    : [_genreChip('Umum')],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _play,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2D1F13),
                                          borderRadius: BorderRadius.circular(28),
                                          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 26),
                                            const SizedBox(width: 10),
                                            Text('Mulai', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _bookmarkBusy ? null : _toggleSave,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          color: _isSaved ? const Color(0xFF865D3B).withOpacity(0.9) : const Color(0xFF2D1F13),
                                          borderRadius: BorderRadius.circular(28),
                                          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _bookmarkBusy
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                  )
                                                : Icon(
                                                    _isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                            const SizedBox(width: 10),
                                            Text(
                                              _isSaved ? 'Tersimpan' : 'Simpan',
                                              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Text('Overview', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                              const SizedBox(height: 12),
                              Text(
                                (_detail?.synopsis.isNotEmpty ?? false) ? _detail!.synopsis : 'Sinopsis belum tersedia.',
                                style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w400, color: Colors.white70, height: 1.5),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _genreChip(String genre) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Text(genre, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
    );
  }
}
