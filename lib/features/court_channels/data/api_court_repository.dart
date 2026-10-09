import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../authentication/data/api_auth_repository.dart';
import '../domain/court_repository.dart';

class ApiCourtRepository implements CourtRepository {
  final ApiAuthRepository _auth;
  final http.Client _client;

  ApiCourtRepository(this._auth, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<List<CourtChannel>> listCourts() async {
    final json = await _request('GET', ApiConfig.endpoint('/courts'), authenticated: false);
    return (json['items']! as List<Object?>).cast<Map<String, Object?>>().map(
      (item) => CourtChannel(
        id: item['id']! as String,
        channelId: item['channelId'] as String?,
        name: item['name']! as String,
        city: (item['city'] ?? 'New Delhi') as String,
        imageKey: item['imageKey'] as String?,
      ),
    ).toList(growable: false);
  }

  @override
  Future<Set<String>> joinedCourtIds() async {
    final json = await _request('GET', ApiConfig.endpoint('/court-subscriptions'));
    return (json['courtIds']! as List<Object?>).cast<String>().toSet();
  }

  @override
  Future<void> setJoined(String courtId, bool joined) async {
    await _request(
      joined ? 'PUT' : 'DELETE',
      ApiConfig.endpoint('/court-subscriptions/$courtId'),
    );
  }

  @override
  Future<List<CourtAnnouncement>> announcements(String channelId) async {
    final json = await _request(
      'GET',
      ApiConfig.endpoint('/channels/$channelId/announcements'),
      authenticated: false,
    );
    return (json['items']! as List<Object?>).cast<Map<String, Object?>>().map(
      (item) => CourtAnnouncement(
        id: item['id']! as String,
        body: item['body']! as String,
        attachmentKey: item['attachmentKey'] as String?,
        revision: (item['revision'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.parse(item['createdAt']! as String),
      ),
    ).toList(growable: false);
  }

  Future<Map<String, Object?>> _request(
    String method,
    Uri uri, {
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'content-type': 'application/json'};
    if (authenticated) headers['authorization'] = 'Bearer ${await _auth.validAccessToken()}';
    final request = switch (method) {
      'PUT' => _client.put(uri, headers: headers),
      'DELETE' => _client.delete(uri, headers: headers),
      _ => _client.get(uri, headers: headers),
    };
    final response = await request.timeout(const Duration(seconds: 12));
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw AuthenticationException(message ?? 'court_request_failed');
    }
    if (decoded is! Map<String, Object?>) {
      throw const AuthenticationException('invalid_server_response');
    }
    return decoded;
  }
}
