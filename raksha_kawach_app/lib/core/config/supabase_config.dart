import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://uijvhpfycmhnedccytiq.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<void> initialize() async {
    if (!isConfigured) {
      if (kDebugMode) {
        debugPrint(
          'SupabaseConfig: SUPABASE_URL or SUPABASE_ANON_KEY not provided. '
          'Provide runtime config with --dart-define-from-file=config/dev.json.',
        );
      }
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        publishableKey: anonKey,
        debug: kDebugMode,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupabaseConfig: Supabase initialization error: $e');
      }
    }
  }
}
