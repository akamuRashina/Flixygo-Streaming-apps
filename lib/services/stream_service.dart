import '../models/api_models.dart';
import '../models/movie_item.dart';
import 'api_client.dart';

class StreamService {
  StreamService._();

  static final StreamService instance = StreamService._();

  final _api = ApiClient.instance;

  Future<StreamData> getStream({
    required ContentType type,
    required String episodeSlug,
    String? quality,
  }) async {
    final typeStr = contentTypeToApi(type);
    final query = quality != null ? {'quality': quality} : null;
    final data = await _api.get(
      '/api/$typeStr/stream/$episodeSlug',
      queryParameters: query,
    );
    return StreamData.fromJson(data as Map<String, dynamic>);
  }
}
