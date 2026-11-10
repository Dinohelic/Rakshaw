import 'supabase_config.dart';

/// Centralized application configuration for Raksha Kawach Admin Portal.
///
/// Reads environment variables injected via build-time `--dart-define` or
/// `--dart-define-from-file=config/dev.json`.
class AppConfig {
  const AppConfig._();

  /// Current application environment: 'development', 'staging', 'production', or 'demo'.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// Whether the app is running in development mode.
  static bool get isDevelopment => environment == 'development';

  /// Whether the app is running in production mode.
  static bool get isProduction => environment == 'production';

  /// Supabase project URL.
  static String get supabaseUrl => SupabaseConfig.url;

  /// Supabase public anonymous API key.
  static String get supabaseAnonKey => SupabaseConfig.anonKey;

  /// Whether valid Supabase credentials have been injected.
  static bool get isSupabaseConfigured => SupabaseConfig.isConfigured;

  /// Application branding
  static const String appName = 'Raksha Kawach';
  static const String appTitle =
      'Raksha Kawach — SGT University Transport Safety and Management System';
}
