class AppConfig {
  /// Override for a real phone:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8080
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}
