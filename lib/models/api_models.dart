/// Data models mirroring the FlixyGo API responses.
/// See: API Reference — /api/anime, /api/kdrama, /api/movie, /api/comments,
/// /api/bookmarks, /api/watch-history.

class EpisodeInfo {
  final int number;
  final String title;
  final String slug;

  const EpisodeInfo({required this.number, required this.title, required this.slug});

  factory EpisodeInfo.fromJson(Map<String, dynamic> json) {
    return EpisodeInfo(
      number: (json['number'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
    );
  }
}

/// Result of GET /api/{anime|kdrama|movie}/detail/:slug
class ContentDetail {
  final String title;
  final String poster;
  final String synopsis;
  final List<String> genres;
  final List<EpisodeInfo> episodes;
  final String? streamUrl; // movies only
  final bool unavailable;

  const ContentDetail({
    required this.title,
    required this.poster,
    required this.synopsis,
    required this.genres,
    required this.episodes,
    this.streamUrl,
    this.unavailable = false,
  });

  factory ContentDetail.fromJson(Map<String, dynamic> json) {
    return ContentDetail(
      title: json['title']?.toString() ?? '',
      poster: json['poster']?.toString() ?? '',
      synopsis: json['synopsis']?.toString() ?? '',
      genres: (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      episodes: (json['episodes'] as List?)
              ?.map((e) => EpisodeInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      streamUrl: json['stream_url']?.toString(),
      unavailable: json['unavailable'] == true,
    );
  }
}

class StreamQuality {
  final String quality;
  final String server;
  final String? streamUrl;
  final String? embedUrl;
  final String? subtitleUrl;

  const StreamQuality({
    required this.quality,
    required this.server,
    this.streamUrl,
    this.embedUrl,
    this.subtitleUrl,
  });

  factory StreamQuality.fromJson(Map<String, dynamic> json) {
    return StreamQuality(
      quality: json['quality']?.toString() ?? '',
      server: json['server']?.toString() ?? '',
      streamUrl: json['stream_url']?.toString(),
      embedUrl: json['embed_url']?.toString(),
      subtitleUrl: json['subtitle_url']?.toString(),
    );
  }
}

/// Result of GET /api/{anime|kdrama}/stream/:episode_slug
class StreamData {
  final String episodeSlug;
  final String? streamUrl;
  final String? embedUrl;
  final String? subtitleUrl;
  final String? requestedQuality;
  final List<StreamQuality> qualities;

  const StreamData({
    required this.episodeSlug,
    this.streamUrl,
    this.embedUrl,
    this.subtitleUrl,
    this.requestedQuality,
    this.qualities = const [],
  });

  /// True if there's anything at all we can hand to a player/WebView.
  bool get isAvailable =>
      (embedUrl != null && embedUrl!.isNotEmpty) || (streamUrl != null && streamUrl!.isNotEmpty);

  factory StreamData.fromJson(Map<String, dynamic> json) {
    return StreamData(
      episodeSlug: json['episode_slug']?.toString() ?? '',
      streamUrl: json['stream_url']?.toString(),
      embedUrl: json['embed_url']?.toString(),
      subtitleUrl: json['subtitle_url']?.toString(),
      requestedQuality: json['requested_quality']?.toString(),
      qualities: (json['qualities'] as List?)
              ?.map((e) => StreamQuality.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class CommentItem {
  final int id;
  final String commentText;
  final String createdAt;
  final String? episodeSlug;
  final String username;
  final String? avatarUrl;

  const CommentItem({
    required this.id,
    required this.commentText,
    required this.createdAt,
    this.episodeSlug,
    required this.username,
    this.avatarUrl,
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    return CommentItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      commentText: json['comment_text']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      episodeSlug: json['episode_slug']?.toString(),
      username: json['username']?.toString() ?? 'Anonim',
    );
  }
}

class WatchHistoryItem {
  final String contentType;
  final String contentSlug;
  final String? episodeSlug;
  final int lastDurationSeconds;
  final String updatedAt;
  final String title;
  final String poster;

  const WatchHistoryItem({
    required this.contentType,
    required this.contentSlug,
    this.episodeSlug,
    required this.lastDurationSeconds,
    required this.updatedAt,
    required this.title,
    required this.poster,
  });

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return WatchHistoryItem(
      contentType: json['content_type']?.toString() ?? 'movie',
      contentSlug: json['content_slug']?.toString() ?? '',
      episodeSlug: json['episode_slug']?.toString(),
      lastDurationSeconds: (json['last_duration_seconds'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      poster: json['poster']?.toString() ?? '',
    );
  }
}

class BookmarkItem {
  final String slug;
  final String title;
  final String poster;
  final String? badge;
  final List<String> genres;
  final String type;
  final String bookmarkedAt;

  const BookmarkItem({
    required this.slug,
    required this.title,
    required this.poster,
    this.badge,
    required this.genres,
    required this.type,
    required this.bookmarkedAt,
  });

  factory BookmarkItem.fromJson(Map<String, dynamic> json) {
    return BookmarkItem(
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      poster: json['poster']?.toString() ?? '',
      badge: json['badge']?.toString(),
      genres: (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      type: json['type']?.toString() ?? 'movie',
      bookmarkedAt: json['bookmarked_at']?.toString() ?? '',
    );
  }
}
