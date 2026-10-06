import 'package:flutter/foundation.dart' show kIsWeb;

/// Deployment environments the app can be configured against.
enum Environment { development, staging, production }

/// Centralized, environment-aware app configuration.
///
/// The active environment is selected at build/run time via:
///   flutter run --dart-define=ENVIRONMENT=staging
/// Defaults to [Environment.development] when not provided.
class AppConfig {
  AppConfig._();

  static const String _envValue = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static final Environment environment = _resolveEnvironment(_envValue);

  // `php artisan serve` binds to loopback only, so Flutter Web (running in
  // the browser on this same machine) must reach it via 127.0.0.1. Native
  // platforms (e.g. a physical Android device on the same Wi-Fi network)
  // can't use loopback — they need this machine's LAN IP instead.
  static const Map<Environment, String> _apiBaseUrls = {
    Environment.development: kIsWeb
        ? 'http://127.0.0.1:8000/api'
        : 'http://192.168.100.13:8000/api',
    Environment.staging: 'https://staging.fsep.example.com/api',
    Environment.production: 'https://api.fsep.example.com/api',
  };

  static String get apiBaseUrl => _apiBaseUrls[environment]!;

  static Duration get connectTimeout => const Duration(seconds: 60);
  static Duration get receiveTimeout => const Duration(seconds: 60);

  static Environment _resolveEnvironment(String value) {
    switch (value) {
      case 'staging':
        return Environment.staging;
      case 'production':
        return Environment.production;
      case 'development':
      default:
        return Environment.development;
    }
  }
}
