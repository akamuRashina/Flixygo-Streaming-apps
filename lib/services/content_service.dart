import '../models/api_models.dart';
import '../models/movie_item.dart';
import 'api_client.dart';

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

  final _api = ApiClient.instance;

  Future<HomeFeed> getHome() async {
    final data = await _api.get('/api/home');
    if (data is! Map) return HomeFeed.empty;

    List<MovieItem> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((item) => MovieItem.fromApiJson(item as Map<String, dynamic>))
          .toList();
    }

    return HomeFeed(
      latestAll: parseList(data['latest_all']),
      popularAll: parseList(data['popular_all']),
      anime: parseList(data['anime']),
      kdrama: parseList(data['kdrama']),
      movies: parseList(data['movies']),
    );
  }

  Future<List<MovieItem>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    final data = await _api.get('/api/search', queryParameters: {'q': query.trim()});
    if (data is! List) return const [];
    return data
        .map((item) => MovieItem.fromApiJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MovieItem>> searchContent({
    required String query,
    String? contentType,
  }) async {
    final all = await search(query);
    if (contentType == null) return all;

    final ContentType type;
    switch (contentType) {
      case 'film':
        type = ContentType.movie;
        break;
      case 'kdrama':
        type = ContentType.kdrama;
        break;
      case 'anime':
        type = ContentType.anime;
        break;
      default:
        return all;
    }

    return all.where((item) => item.contentType == type).toList();
  }

  Future<ContentDetail> getDetail({
    required ContentType type,
    required String slug,
  }) async {
    final typeStr = contentTypeToApi(type);
    final data = await _api.get('/api/$typeStr/detail/$slug');
    return ContentDetail.fromJson(data as Map<String, dynamic>);
  }
}
