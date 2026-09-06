import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:media_kit/media_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize MediaKit with error handling
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('MediaKit initialization warning: $e');
    // Continue anyway - some platforms may not need it
  }

  // Check Supabase configuration only if not in release mode without keys
  if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
    if (!Env.isConfigured) {
      // In release mode, show error screen instead of crashing
      runApp(const SupabaseErrorApp());
      return;
    }

    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
      // Show error screen
      runApp(SupabaseErrorApp(error: e.toString()));
      return;
    }
  }

  runApp(const FlixyGoApp());
}

class FlixyGoApp extends StatelessWidget {
  const FlixyGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlixyGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginPage(),
    );
  }
}

// Error screen for Supabase configuration issues
class SupabaseErrorApp extends StatelessWidget {
  final String? error;
  
  const SupabaseErrorApp({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlixyGo - Configuration Error',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF18120C),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFDE903A),
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Configuration Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  error ?? 'Supabase belum dikonfigurasi.\n\n'
                      'Aplikasi ini memerlukan konfigurasi Supabase.\n'
                      'Hubungi developer untuk informasi lebih lanjut.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
