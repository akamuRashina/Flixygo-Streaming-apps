/// The REST `ApiClient` is gone now that every service talks to Supabase
/// directly — but `ApiException` is kept under this same filename so
/// `login_page.dart`, `movie_detail_page.dart`, and
/// `anime_kdrama_detail_page.dart` (which do `import '../services/api_client.dart'`
/// and `catch (e) { e is ApiException ? ... }`) keep working without changes.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Wraps any Supabase error (AuthException, PostgrestException,
/// StorageException, etc.) into our own [ApiException] so every service
/// and page can keep catching a single exception type.
ApiException wrapSupabaseError(Object error) {
  try {
    final dynamic e = error;
    final m = e.message;
    if (m is String && m.isNotEmpty) return ApiException(m);
  } catch (_) {
    // Not an object with a `.message` getter — fall through.
  }
  return ApiException(error.toString());
}
