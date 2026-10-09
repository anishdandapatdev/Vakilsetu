class ApiConfig {
  ApiConfig._();

  static const enabled = bool.fromEnvironment('API_ENABLED', defaultValue: false);
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080/v1',
  );

  static Uri endpoint(String path) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final suffix = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$suffix');
  }
}
