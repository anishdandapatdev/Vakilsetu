import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  /// Defaults to true so the app connects to the VakilSetu phone OTP backend.
  static const enabled = bool.fromEnvironment('API_ENABLED', defaultValue: true);

  /// Automatically resolves to 10.0.2.2 on Android Emulators and 127.0.0.1 on Desktop/Web.
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/v1';
    }
    return 'http://127.0.0.1:8080/v1';
  }

  static Uri endpoint(String path) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final suffix = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$suffix');
  }
}
