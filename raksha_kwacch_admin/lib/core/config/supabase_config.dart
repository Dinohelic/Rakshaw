import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure build-time configuration for Supabase integration.
///
/// Reads environment variables injected via `--dart-define` or
/// `--dart-define-from-file=config/dev.json` so sensitive keys are never
/// committed or hardcoded into source files.
class SupabaseConfig {
  /// Confirmed SGT University Supabase project URL.
  static const String defaultUrl = 'https://uijvhpfycmhnedccytiq.supabase.co';

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: defaultUrl,
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Whether Supabase credentials have been injected via build arguments or dev.json.
  static bool get isConfigured =>
      url.isNotEmpty && anonKey.isNotEmpty && anonKey != 'YOUR_PUBLIC_KEY_HERE';

  /// Safely initializes Supabase if credentials are provided at build time.
  static Future<bool> safeInitialize() async {
    if (!isConfigured) {
      if (kDebugMode) {
        debugPrint(
          'SupabaseConfig: No valid SUPABASE_ANON_KEY provided. Running in Demo Mode fallback.',
        );
      }
      return false;
    }

    try {
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: anonKey,
        debug: kDebugMode,
      );
      if (kDebugMode) {
        debugPrint(
          'SupabaseConfig: Supabase initialized successfully for $url',
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseConfig: Initialization error: $e');
      }
      return false;
    }
  }

  /// Helper to get the current Supabase instance if initialized.
  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
