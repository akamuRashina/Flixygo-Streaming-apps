import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/api_models.dart';
import 'api_client.dart';

/// `bookmarks` table (per schema.sql):
///   id            bigserial primary key
///   user_id       uuid references profiles(id)
///   content_type  text  check ('anime' | 'kdrama' | 'movie')
///   content_slug  text
///   created_at    timestamptz default now()
///   unique (user_id, content_type, content_slug)
///
/// NOTE: the table's primary key is the autoincrement `id`, not the
/// natural (user_id, content_type, content_slug) key — so `upsert()`
/// must pass `onConflict` explicitly, or Postgres will conflict-check
/// against `id` (which is always new) and just insert duplicate rows.
///
/// We only store the (user, type, slug) triple — title/poster/genres are
/// hydrated by joining against the `movies`/`anime`/`kdrama` tables when
/// listing, so this stays in sync automatically if that content changes.
class BookmarkService {
  BookmarkService._();

  static final BookmarkService instance = BookmarkService._();

  SupabaseClient get _client => Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw ApiException('Anda belum masuk.');
    return uid;
  }

  Future<List<BookmarkItem>> list() async {
    try {
      final uid = _requireUid();
      final rows = await _client
          .from('bookmarks')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      final bookmarkRows = (rows as List).cast<Map<String, dynamic>>();

      final hydrated = <BookmarkItem>[];
      for (final type in ['movie', 'anime', 'kdrama']) {
        final matching = bookmarkRows.where((r) => r['content_type'] == type).toList();
        if (matching.isEmpty) continue;

        final table = type == 'movie' ? 'movies' : type;
        final slugs = matching.map((r) => r['content_slug'] as String).toSet().toList();
        final content = await _client
            .from(table)
            .select('slug, title, poster, badge, genres')
            .filter('slug', 'in', '(${slugs.join(',')})');
        final bySlug = {for (final c in content) c['slug'] as String: c};

        for (final r in matching) {
          final c = bySlug[r['content_slug']];
          hydrated.add(BookmarkItem(
            slug: r['content_slug'] as String,
            title: c?['title']?.toString() ?? r['content_slug'] as String,
            poster: c?['poster']?.toString() ?? '',
            badge: c?['badge']?.toString(),
            genres: (c?['genres'] as List?)?.map((e) => e.toString()).toList() ?? const [],
            type: type,
            bookmarkedAt: r['created_at']?.toString() ?? '',
          ));
        }
      }
      return hydrated;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw wrapSupabaseError(e);
    }
  }

  Future<void> add({required String contentType, required String contentSlug}) async {
    try {
      final uid = _requireUid();
      await _client.from('bookmarks').upsert(
        {
          'user_id': uid,
          'content_type': contentType,
          'content_slug': contentSlug,
        },
        onConflict: 'user_id,content_type,content_slug',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw wrapSupabaseError(e);
    }
  }

  Future<void> remove({required String contentType, required String contentSlug}) async {
    try {
      final uid = _requireUid();
      await _client
          .from('bookmarks')
          .delete()
          .eq('user_id', uid)
          .eq('content_type', contentType)
          .eq('content_slug', contentSlug);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw wrapSupabaseError(e);
    }
  }
}
