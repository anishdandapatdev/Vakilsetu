import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/domain/identity.dart';
import '../../authentication/data/api_auth_repository.dart';
import '../../profile/domain/advocate_profile.dart';
import '../domain/directory_repository.dart';

class ApiAdvocatesRepository implements DirectoryRepository, ProfileRepository {
  final ApiAuthRepository _auth;
  final http.Client _client;

  ApiAdvocatesRepository(this._auth, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<AdvocatePage> search({
    required String query,
    String? courtId,
    String? cursor,
  }) async {
    final offset = int.tryParse(cursor ?? '') ?? 0;
    final uri = ApiConfig.endpoint('/advocates').replace(queryParameters: {
      if (query.trim().isNotEmpty) 'query': query.trim(),
      if (courtId != null) 'courtId': courtId,
      'limit': '20',
      'offset': '$offset',
    });
    final json = await _request('GET', uri);
    final items = (json['items']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(_profile)
        .toList();
    return AdvocatePage(items, items.length == 20 ? '${offset + 20}' : null);
  }

  @override
  Future<AdvocateProfile?> getMine() async {
    final json = await _request('GET', ApiConfig.endpoint('/advocates/me'));
    return json.isEmpty ? null : _profile(json);
  }

  @override
  Future<AdvocateProfile> save(ProfileUpdate update) async {
    final json = await _request(
      'PUT',
      ApiConfig.endpoint('/advocates/me'),
      body: {
        'fullName': update.fullName,
        'enrollmentNumber': update.enrollmentNumber,
        'primaryCourtId': update.primaryCourtId,
      },
    );
    return _profile(json);
  }

  @override
  Future<Map<String, String>> listCourtIdsByName() async {
    final json = await _request('GET', ApiConfig.endpoint('/courts'));
    return {
      for (final court in (json['items']! as List<Object?>).cast<Map<String, Object?>>())
        court['name']! as String: court['id']! as String,
    };
  }

  Future<Map<String, Object?>> _request(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    final token = await _auth.validAccessToken();
    final headers = {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
    };
    final response = method == 'PUT'
        ? await _client.put(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 12))
        : await _client.get(uri, headers: headers).timeout(const Duration(seconds: 12));
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw AuthenticationException(message ?? 'advocates_request_failed');
    }
    if (decoded == null) return const {};
    if (decoded is! Map<String, Object?>) {
      throw const AuthenticationException('invalid_server_response');
    }
    return decoded;
  }

  AdvocateProfile _profile(Map<String, Object?> json) => AdvocateProfile(
    id: (json['accountId'] ?? json['id'] ?? '') as String,
    fullName: (json['fullName'] ?? 'Advocate') as String,
    enrollmentNumber: (json['enrollmentNumber'] ?? '') as String,
    primaryCourtId: (json['courtId'] ?? json['primaryCourtId'] ?? '') as String,
    primaryCourtName: json['primaryCourt'] as String?,
    photoKey: json['photoKey'] as String?,
    verification: switch (json['verificationStatus'] ?? (json['verified'] == true ? 'verified' : 'pending')) {
      'verified' => VerificationStatus.verified,
      'rejected' || 'suspended' => VerificationStatus.rejected,
      _ => VerificationStatus.pending,
    },
  );
}
