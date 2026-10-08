class AppConfig {
  /// Override at run time, e.g. for a real phone:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8080
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}
