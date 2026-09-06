/// Supabase credentials, injected at build/run time via --dart-define
/// (see SUPABASE_SETUP.md). Never hardcode real values here and never
/// commit `supabase-keys.json` to source control.
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
