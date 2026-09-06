import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/api_models.dart';
import '../models/movie_item.dart';
import 'api_client.dart';

/// Reads a single episode's playback info from `anime_episodes` or
/// `kdrama_episodes` (per schema.sql — these are separate tables, each
/// keyed by `slug`, not a unified `episodes` table with a `content_type`
/// column).
///
/// Movies don't use this — they get `stream_url`/`embed_url` straight
/// from the `movies` row via `ContentService.getDetail`.
class StreamService {
  StreamService._();

  static final StreamService instance = StreamService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<StreamData> getStream({
    required ContentType type,
    required String episodeSlug,
    String? quality,
  }) async {
    assert(type != ContentType.movie, 'Movies do not use the stream endpoint');
    try {
      final table = type == ContentType.anime ? 'anime_episodes' : 'kdrama_episodes';
      final row = await _client.from(table).select().eq('slug', episodeSlug).single();

      return StreamData(
        // The table's primary key column is `slug`, not `episode_slug` —
        // map it across manually rather than via StreamData.fromJson.
        episodeSlug: row['slug']?.toString() ?? episodeSlug,
        streamUrl: row['stream_url']?.toString(),
        embedUrl: row['embed_url']?.toString(),
        subtitleUrl: row['subtitle_url']?.toString(),
        requestedQuality: quality,
        qualities: (row['qualities'] as List?)
                ?.map((e) => StreamQuality.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
    } catch (e) {
      throw wrapSupabaseError(e);
    }
  }
}
