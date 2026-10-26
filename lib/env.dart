/// Environment configuration injected via --dart-define or defaults.
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lgjamkiezogqzatunmyq.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxnamFta2llem9ncXphdHVubXlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwMjkxOTksImV4cCI6MjEwMDYwNTE5OX0.ogY4Qd8p6CA_iJiINTXyvQsZXI1JAgYefkQlui29VHc',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://flixy-go.vercel.app',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
