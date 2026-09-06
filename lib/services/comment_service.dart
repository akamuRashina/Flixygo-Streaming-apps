import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/api_models.dart';
import 'api_client.dart';

/// `comments` table (per schema.sql):
///   id            bigserial primary key
///   user_id       uuid references profiles(id)
///   content_type  text  check ('anime' | 'kdrama' | 'movie')
///   content_slug  text
///   episode_slug  text  nullable
///   comment_text  text
///   created_at    timestamptz default now()
///
/// NOTE: there's no `username` column on `comments` itself — the
/// username lives on `profiles` (linked via `user_id`), so `list()`
/// embeds it with `profiles(username)` rather than reading it straight
/// off the row.
///
/// RLS: SELECT is open to everyone; INSERT/DELETE are restricted to
/// `user_id = auth.uid()` (no UPDATE policy — comments aren't editable,
/// matching the old API).
class CommentService {
  CommentService._();

  static final CommentService instance = CommentService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<CommentItem>> list({
    required String contentType,
    required String contentSlug,
    String? episodeSlug,
  }) async {
    try {
      final builder = _client
          .from('comments')
          .select('id, comment_text, created_at, episode_slug, profiles(username, avatar_url)')
          .eq('content_type', contentType)
          .eq('content_slug', contentSlug);
      final filtered = episodeSlug != null ? builder.eq('episode_slug', episodeSlug) : builder;
      final rows = await filtered.order('created_at', ascending: false);

      return (rows as List).cast<Map<String, dynamic>>().map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        return CommentItem(
          id: (row['id'] as num?)?.toInt() ?? 0,
          commentText: row['comment_text']?.toString() ?? '',
          createdAt: row['created_at']?.toString() ?? '',
          episodeSlug: row['episode_slug']?.toString(),
          username: profile?['username']?.toString() ?? 'Anonim',
          avatarUrl: profile?['avatar_url']?.toString(),
        );
      }).toList();
    } catch (e) {
      throw wrapSupabaseError(e);
    }
  }

  Future<void> add({
    required String contentType,
    required String contentSlug,
    String? episodeSlug,
    required String commentText,
  }) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw ApiException('Anda belum masuk.');
      await _client.from('comments').insert({
        'user_id': uid,
        'content_type': contentType,
        'content_slug': contentSlug,
        'episode_slug': episodeSlug,
        'comment_text': commentText,
      });
    } catch (e) {
      if (e is ApiException) rethrow;
      throw wrapSupabaseError(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _client.from('comments').delete().eq('id', id);
    } catch (e) {
      throw wrapSupabaseError(e);
    }
  }
}
