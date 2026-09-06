import 'package:flutter/material.dart';

enum ContentType { movie, anime, kdrama }

ContentType contentTypeFromApi(String? type) {
  switch (type) {
    case 'anime':
      return ContentType.anime;
    case 'kdrama':
      return ContentType.kdrama;
    default:
      return ContentType.movie;
  }
}

String contentTypeToApi(ContentType type) {
  switch (type) {
    case ContentType.anime:
      return 'anime';
    case ContentType.kdrama:
      return 'kdrama';
    case ContentType.movie:
      return 'movie';
  }
}

/// Unified card/detail model. Populated from the real API — `slug` is what
/// every detail/stream/bookmark/comment/history call keys off of.
class MovieItem {
  final String title;
  final String rating;
  final String imageUrl;
  final List<Color> fallbackGradient;
  final ContentType contentType;
  final List<String> genres;
  final String overview;
  final int episodeCount;
  final String slug;
  final String? badge;

  const MovieItem({
    required this.title,
    this.rating = '-',
    required this.imageUrl,
    this.fallbackGradient = const [Color(0xFF3B2A1B), Color(0xFF1B120A)],
    this.contentType = ContentType.movie,
    this.genres = const [],
    this.overview = '',
    this.episodeCount = 0,
    this.slug = '',
    this.badge,
  });

  /// Builds a card-level item from a home/search API entry:
  /// `{ title, poster, slug, badge, genres, type }`.
  factory MovieItem.fromApiJson(Map<String, dynamic> json) {
    final genresList = (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final badge = json['badge']?.toString();
    return MovieItem(
      title: json['title']?.toString() ?? 'Tanpa judul',
      rating: (badge != null && badge.isNotEmpty) ? badge : '-',
      imageUrl: json['poster']?.toString() ?? '',
      contentType: contentTypeFromApi(json['type']?.toString()),
      genres: genresList,
      slug: json['slug']?.toString() ?? '',
      badge: badge,
    );
  }

  MovieItem copyWith({
    String? title,
    String? rating,
    String? imageUrl,
    ContentType? contentType,
    List<String>? genres,
    String? overview,
    int? episodeCount,
    String? slug,
    String? badge,
  }) {
    return MovieItem(
      title: title ?? this.title,
      rating: rating ?? this.rating,
      imageUrl: imageUrl ?? this.imageUrl,
      fallbackGradient: fallbackGradient,
      contentType: contentType ?? this.contentType,
      genres: genres ?? this.genres,
      overview: overview ?? this.overview,
      episodeCount: episodeCount ?? this.episodeCount,
      slug: slug ?? this.slug,
      badge: badge ?? this.badge,
    );
  }
}
