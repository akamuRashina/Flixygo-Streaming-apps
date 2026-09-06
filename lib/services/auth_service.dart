import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';

/// Handles register/login/logout via Supabase Auth.
///
/// Supabase Auth is email-based, but FlixyGo's UI only collects a
/// username + password. We map `username` -> `<username>@flixygo.app`
/// as a placeholder email and store the real username in `user_metadata`.
/// If you'd rather collect a real email at signup, swap `_fakeEmail` out
/// for an actual email field.
///
/// IMPORTANT: in your Supabase project (Authentication -> Providers ->
/// Email), either disable "Confirm email" so `signUp` returns a session
/// immediately, or add a "check your inbox" step to the UI — right now
/// `register()` assumes a session comes back straight away, matching the
/// old backend's behavior.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  String _fakeEmail(String username) =>
      '${username.trim().toLowerCase()}@flixygo.app';

  Future<String?> getToken() async {
    return _client.auth.currentSession?.accessToken;
  }

  Future<String?> getUsername() async {
    final user = _client.auth.currentUser;
    final metaUsername = user?.userMetadata?['username']?.toString();
    if (metaUsername != null && metaUsername.isNotEmpty) return metaUsername;
    return user?.email?.split('@').first;
  }

  Future<String?> getUserId() async {
    return _client.auth.currentUser?.id;
  }

  Future<bool> isLoggedIn() async {
    return _client.auth.currentSession != null;
  }

  /// Throws [ApiException] on failure (e.g. username already taken).
  Future<void> register({required String username, required String password}) async {
    try {
      final res = await _client.auth.signUp(
        email: _fakeEmail(username),
        password: password,
        data: {'username': username.trim()},
      );
      if (res.session == null) {
        throw ApiException(
          'Registrasi berhasil, tapi butuh konfirmasi email. '
          'Nonaktifkan "Confirm email" di Supabase Auth settings untuk '
          'perilaku login-langsung seperti sebelumnya.',
        );
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase().contains('already registered')
          ? 'Username sudah dipakai.'
          : e.message;
      throw ApiException(msg);
    }
  }

  /// Throws [ApiException] on failure (e.g. invalid credentials).
  Future<void> login({required String username, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: _fakeEmail(username),
        password: password,
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase().contains('invalid login credentials')
          ? 'Username atau password salah.'
          : e.message;
      throw ApiException(msg);
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }
}
