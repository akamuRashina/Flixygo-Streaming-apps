import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/api_models.dart';
import 'api_client.dart';

/// `watch_history` table (per schema.sql):
///   id                    bigserial primary key
///   user_id               uuid references profiles(id)
///   content_type          text  check ('anime' | 'kdrama' | 'movie')
///   content_slug          text
///   episode_slug          text  nullable (null for movies)
///   last_duration_seconds int
///   updated_at            timestamptz default now()
///
/// NOTE: the "one row per (user, content, episode)" rule is enforced by
/// a *functional* unique index —
///   unique (user_id, content_type, content_slug, coalesce(episode_slug, ''))
/// — not a plain column-list constraint. Supabase's `upsert(onConflict: ...)`
/// can only target a literal column list, so it can't resolve against this
/// index. `update()` below does a manual select-then-write instead.
class WatchHistoryService {
  WatchHistoryService._();

  static final WatchHistoryService instance = WatchHistoryService._();

  SupabaseClient get _client => Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw ApiException('Anda belum masuk.');
    return uid;
  }

  Future<List<WatchHistoryItem>> list() async {
    try {
      final uid = _requireUid();
      final rows = await _client
          .from('watch_history')
          .select()
          .eq('user_id', uid)
          .order('updated_at', ascending: false);
      final historyRows = (rows as List).cast<Map<String, dynamic>>();

      final hydrated = <WatchHistoryItem>[];
      for (final type in ['movie', 'anime', 'kdrama']) {
        final matching = historyRows.where((r) => r['content_type'] == type).toList();
        if (matching.isEmpty) continue;

        final table = type == 'movie' ? 'movies' : type;
        final slugs = matching.map((r) => r['content_slug'] as String).toSet().toList();
        final content = await _client
            .from(table)
            .select('slug, title, poster')
            .filter('slug', 'in', '(${slugs.join(',')})');
        final bySlug = {for (final c in content) c['slug'] as String: c};

        for (final r in matching) {
          final c = bySlug[r['content_slug']];
          hydrated.add(WatchHistoryItem(
            contentType: type,
            contentSlug: r['content_slug'] as String,
            episodeSlug: r['episode_slug']?.toString(),
            lastDurationSeconds: (r['last_duration_seconds'] as num?)?.toInt() ?? 0,
            updatedAt: r['updated_at']?.toString() ?? '',
            title: c?['title']?.toString() ?? r['content_slug'] as String,
            poster: c?['poster']?.toString() ?? '',
          ));
        }
      }
      return hydrated;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw wrapSupabaseError(e);
    }
  }

  /// Call periodically (every ~10-15s) while a video is playing so progress
  /// is saved. `episodeSlug` should be omitted/null for movies.
  Future<void> update({
    required String contentType,
    required String contentSlug,
    String? episodeSlug,
    required int lastDurationSeconds,
  }) async {
    try {
      final uid = _requireUid();

      var query = _client
          .from('watch_history')
          .select('id')
          .eq('user_id', uid)
          .eq('content_type', contentType)
          .eq('content_slug', contentSlug);
      query = episodeSlug != null
          ? query.eq('episode_slug', episodeSlug)
          : query.isFilter('episode_slug', null);
      final existing = await query.maybeSingle();

      final payload = {
        'user_id': uid,
        'content_type': contentType,
        'content_slug': contentSlug,
        'episode_slug': episodeSlug,
        'last_duration_seconds': lastDurationSeconds,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing != null) {
        await _client.from('watch_history').update(payload).eq('id', existing['id']);
      } else {
        await _client.from('watch_history').insert(payload);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw wrapSupabaseError(e);
    }
  }
}
