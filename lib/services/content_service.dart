import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/api_models.dart';
import '../models/movie_item.dart';
import 'api_client.dart';

/// Reads the content catalog straight from your Supabase tables (matches
/// schema.sql) instead of the old `/api/home` / `/api/search` /
/// `/api/{type}/detail/:slug` REST endpoints.
///
/// Tables used (per schema.sql):
///   movies(slug pk, title, poster, synopsis, badge, genres text[],
///          stream_url, embed_url, unavailable bool, source, updated_at)
///   anime(slug pk, title, poster, synopsis, badge, genres text[],
///         source, updated_at)
///   kdrama(same shape as anime)
///   anime_episodes(slug pk, anime_slug fk, number, title, stream_url,
///                  embed_url, subtitle_url, qualities jsonb, ...)
///   kdrama_episodes(same shape, keyed by kdrama_slug)
///
/// NOTE: schema.sql has no popularity/view-count column anywhere, so
/// "popular" below is a placeholder ordering, not a real ranking — see
/// the TODO on `_fetchPopular`.
class HomeFeed {
  final List<MovieItem> latestAll;
  final List<MovieItem> popularAll;
  final List<MovieItem> anime;
  final List<MovieItem> kdrama;
  final List<MovieItem> movies;

  const HomeFeed({
    required this.latestAll,
    required this.popularAll,
    required this.anime,
    required this.kdrama,
    required this.movies,
  });

  static const empty = HomeFeed(
    latestAll: [],
    popularAll: [],
    anime: [],
    kdrama: [],
    movies: [],
  );
}

class ContentService {
  ContentService._();

  static final ContentService instance = ContentService._();

  SupabaseClient get _client => Supabase.instance.client;

  static const Map<ContentType, String> _tableFor = {
    ContentType.movie: 'movies',
    ContentType.anime: 'anime',
    ContentType.kdrama: 'kdrama',
  };

  MovieItem _rowToItem(Map<String, dynamic> row, ContentType type) {
    final badge = row['badge']?.toString();
    return MovieItem(
      title: row['title']?.toString() ?? 'Tanpa judul',
      rating: (badge != null && badge.isNotEmpty) ? badge : '-',
      imageUrl: row['poster']?.toString() ?? '',
      contentType: type,
      genres: (row['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      slug: row['slug']?.toString() ?? '',
      badge: badge,
    );
  }

  Future<List<MovieItem>> _fetchLatest(ContentType type, {int limit = 20}) async {
    final rows = await _client
        .from(_tableFor[type]!)
        .select()
        .order('updated_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map((r) => _rowToItem(r, type)).toList();
  }

  /// TODO: schema.sql has no popularity/view-count column, so this just
  /// orders by `updated_at` ascending as a placeholder (so it's at least
  /// not an exact duplicate of `_fetchLatest`). Add a real metric — e.g.
  /// `views int default 0` on movies/anime/kdrama, bumped whenever a
  /// detail page loads — and swap the `order()` call below once it exists.
  Future<List<MovieItem>> _fetchPopular({int limit = 15}) async {
    final results = <MovieItem>[];
    for (final type in ContentType.values) {
      final rows = await _client
          .from(_tableFor[type]!)
          .select()
          .order('updated_at', ascending: true)
          .limit(limit);
      results.addAll((rows as List).cast<Map<String, dynamic>>().map((r) => _rowToItem(r, type)));
    }
    return results.take(limit).toList();
  }

  Future<HomeFeed> getHome() async {
    try {
      final movies = await _fetchLatest(ContentType.movie);
      final anime = await _fetchLatest(ContentType.anime);
      final kdrama = await _fetchLatest(ContentType.kdrama);
      final popularAll = await _fetchPopular();

      final latestAll = [...movies, ...anime, ...kdrama].take(15).toList();

      return HomeFeed(
        latestAll: latestAll,
        popularAll: popularAll,
        anime: anime,
        kdrama: kdrama,
        movies: movies,
      );
    } catch (e) {
      throw wrapSupabaseError(e);
    }
  }

  Future<List<MovieItem>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final results = <MovieItem>[];
      for (final type in ContentType.values) {
        final rows = await _client
            .from(_tableFor[type]!)
            .select()
            .ilike('title', '%${query.trim()}%')
            .limit(20);
        results.addAll((rows as List).cast<Map<String, dynamic>>().map((r) => _rowToItem(r, type)));
      }
      return results;
    } catch (e) {
      throw wrapSupabaseError(e);
    }
  }

  Future<ContentDetail> getDetail({required ContentType type, required String slug}) async {
    try {
      final row = await _client.from(_tableFor[type]!).select().eq('slug', slug).single();

      List<EpisodeInfo> episodes = const [];
      if (type == ContentType.anime) {
        final epRows = await _client
            .from('anime_episodes')
            .select('number, title, slug')
            .eq('anime_slug', slug)
            .order('number');
        episodes = (epRows as List).cast<Map<String, dynamic>>().map(EpisodeInfo.fromJson).toList();
      } else if (type == ContentType.kdrama) {
        final epRows = await _client
            .from('kdrama_episodes')
            .select('number, title, slug')
            .eq('kdrama_slug', slug)
            .order('number');
        episodes = (epRows as List).cast<Map<String, dynamic>>().map(EpisodeInfo.fromJson).toList();
      }

      return ContentDetail(
        title: row['title']?.toString() ?? '',
        poster: row['poster']?.toString() ?? '',
        synopsis: row['synopsis']?.toString() ?? '',
        genres: (row['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        episodes: episodes,
        // movies has both stream_url and embed_url — prefer the direct
        // stream_url, fall back to embed_url if that's all that's set.
        streamUrl: (row['stream_url']?.toString().isNotEmpty ?? false)
            ? row['stream_url'].toString()
            : row['embed_url']?.toString(),
        unavailable: row['unavailable'] == true,
      );
    } catch (e) {
      throw wrapSupabaseError(e);
    }
  }
}
