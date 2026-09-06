import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';

/// Profile photos live in the Supabase Storage bucket `avatars` (public
/// bucket), at path `<user_id>/avatar.<ext>`, with the resulting public
/// URL cached on `profiles.avatar_url` for fast reads. See
/// SUPABASE_SETUP.md for the bucket + column + storage-policy SQL.
///
/// This makes the photo sync across devices and lets other users' avatars
/// show up too (e.g. next to their comments) — unlike the old local-only
/// version.
class ProfilePhotoService {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();

  static const _bucket = 'avatars';

  SupabaseClient get _client => Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  /// Current user's avatar URL, or null if logged out / no photo set.
  Future<String?> getPhotoUrl() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row =
          await _client.from('profiles').select('avatar_url').eq('id', uid).maybeSingle();
      final url = row?['avatar_url']?.toString();
      return (url != null && url.isNotEmpty) ? url : null;
    } catch (_) {
      return null;
    }
  }

  /// Opens a file picker, uploads the chosen image to Supabase Storage,
  /// and updates `profiles.avatar_url`. Returns the new public URL, or
  /// null if the picker was cancelled.
  Future<String?> pickAndSavePhoto() async {
    final uid = _uid;
    if (uid == null) throw ApiException('Anda belum masuk.');

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // needed on web/desktop where `.path` may be null
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final bytes = picked.bytes ??
        (picked.path != null ? await File(picked.path!).readAsBytes() : null);
    if (bytes == null) return null;

    final ext = (picked.extension ?? 'jpg').toLowerCase();
    final path = '$uid/avatar.$ext';

    try {
      await _client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: _contentTypeFor(ext)),
          );

      // Cache-bust so the app shows the new photo immediately instead of
      // a stale CDN/browser-cached copy at the same URL.
      final publicUrl = _client.storage.from(_bucket).getPublicUrl(path);
      final bustedUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      // Chain .select() so we can tell the difference between "updated
      // successfully" and "RLS silently allowed the call but touched 0
      // rows" — Postgrest doesn't throw for the latter, it just returns
      // an empty list, which otherwise looks identical to success.
      final updated = await _client
          .from('profiles')
          .update({'avatar_url': bustedUrl})
          .eq('id', uid)
          .select();
      if ((updated as List).isEmpty) {
        throw ApiException(
          'Foto berhasil diunggah, tapi gagal disimpan ke profil. '
          'Tabel `profiles` kemungkinan belum punya RLS policy UPDATE '
          'untuk baris milik sendiri — lihat SUPABASE_SETUP.md.',
        );
      }
      return bustedUrl;
    } catch (e) {
      throw wrapSupabaseError(e);
    }
  }

  Future<void> clearPhoto() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      // Best-effort remove — we don't know which extension was used.
      await _client.storage.from(_bucket).remove(
            ['jpg', 'jpeg', 'png', 'webp', 'gif'].map((ext) => '$uid/avatar.$ext').toList(),
          );
    } catch (_) {
      // Non-fatal — clearing the DB pointer below is what actually matters.
    }
    try {
      final updated = await _client
          .from('profiles')
          .update({'avatar_url': null})
          .eq('id', uid)
          .select();
      if ((updated as List).isEmpty) {
        throw ApiException(
          'Gagal menghapus foto dari profil. Tabel `profiles` kemungkinan '
          'belum punya RLS policy UPDATE untuk baris milik sendiri.',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw wrapSupabaseError(e);
    }
  }

  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}
