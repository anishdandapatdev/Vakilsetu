import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../authentication/data/api_auth_repository.dart';
import '../domain/push_registration_repository.dart';

class ApiPushRegistrationRepository implements PushRegistrationRepository {
  final ApiAuthRepository _auth;
  final http.Client _client;
  ApiPushRegistrationRepository(this._auth, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<String> register({required PushProvider provider, required String token}) async {
    if (token.length < 20) throw const PushRegistrationException('push_token_invalid');
    final json = await _request('POST', body: {'provider': provider.name, 'token': token});
    return json['registrationId']! as String;
  }

  @override
  Future<void> remove(String registrationId) async {
    await _request('DELETE', registrationId: registrationId);
  }

  Future<Map<String, Object?>> _request(
    String method, {
    String? registrationId,
    Map<String, Object?>? body,
  }) async {
    final headers = {
      'authorization': 'Bearer ${await _auth.validAccessToken()}',
      'content-type': 'application/json',
    };
    final uri = ApiConfig.endpoint(
      registrationId == null ? '/push-registrations' : '/push-registrations/$registrationId',
    );
    final response = method == 'POST'
        ? await _client.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 12))
        : await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 12));
    if (response.statusCode == 204) return const {};
    Object? decoded;
    try { decoded = jsonDecode(response.body); } on FormatException { decoded = null; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw PushRegistrationException(message ?? 'push_registration_failed');
    }
    if (decoded is! Map<String, Object?>) {
      throw const PushRegistrationException('invalid_server_response');
    }
    return decoded;
  }
}

class PushRegistrationException implements Exception {
  final String code;
  const PushRegistrationException(this.code);
  @override
  String toString() => code;
}
