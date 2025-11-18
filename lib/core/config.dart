/// Global configuration for API endpoints and environment-specific helpers.
class AppConfig {
  AppConfig._();

  /// Base API URL for backend.
  ///
  /// - Android emulator: use 10.0.2.2
  /// - iOS simulator: use localhost
  /// - Physical device: use machine IP on same network
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  /// Returns the full URL for an endpoint path.
  static String endpoint(String path) => '$apiBaseUrl$path';
}

