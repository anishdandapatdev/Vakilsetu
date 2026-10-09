import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../../../core/domain/identity.dart';
import '../domain/auth_repository.dart';
import 'secure_session_store.dart';

class AuthenticationException implements Exception {
  final String code;
  const AuthenticationException(this.code);
  @override
  String toString() => code;
}

class ApiAuthRepository implements AuthRepository {
  final http.Client _client;
  final SecureSessionStore _sessions;

  ApiAuthRepository({http.Client? client, SecureSessionStore? sessions})
    : _client = client ?? http.Client(),
      _sessions = sessions ?? const SecureSessionStore();

  @override
  Future<String> requestOtp(String phoneNumber) async {
    final response = await _post('/auth/otp/request', {'phone': phoneNumber});
    return response['challengeId']! as String;
  }

  @override
  Future<SessionIdentity> verifyOtp(String challengeId, String code) async {
    final deviceKey = await _developmentRegistrationKey();
    final response = await _post('/auth/otp/verify', {
      'challengeId': challengeId,
      'code': code,
      'platform': _platform,
      'publicIdentityKey': deviceKey,
    });
    final expiresIn = response['accessExpiresInSeconds']! as int;
    final session = StoredSession(
      accountId: response['accountId']! as String,
      deviceId: response['deviceId']! as String,
      accessToken: response['accessToken']! as String,
      refreshToken: response['refreshToken']! as String,
      accessExpiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      deviceStatus: response['deviceStatus']! as String,
    );
    await _sessions.write(session);
    return _identity(session);
  }

  @override
  Future<SessionIdentity?> restoreSession() async {
    var session = await _sessions.read();
    if (session == null) return null;
    if (session.accessExpiresAt.isBefore(
      DateTime.now().add(const Duration(seconds: 30)),
    )) {
      session = await _refresh(session);
    }
    return _identity(session);
  }

  Future<String> validAccessToken() async {
    var session = await _sessions.read();
    if (session == null) throw const AuthenticationException('session_missing');
    if (session.accessExpiresAt.isBefore(
      DateTime.now().add(const Duration(seconds: 30)),
    )) {
      session = await _refresh(session);
    }
    return session.accessToken;
  }

  @override
  Future<void> signOut() async {
    final session = await _sessions.read();
    try {
      if (session != null) {
        await _post('/auth/otp/logout', const {}, bearer: session.accessToken);
      }
    } finally {
      await _sessions.clear();
    }
  }

  @override
  Future<SessionIdentity> signInWithEmail(String email, String password) =>
      throw const AuthenticationException('email_sign_in_not_available');

  @override
  Future<void> revokeDevice(String deviceId) =>
      throw const AuthenticationException('device_revocation_not_wired');

  Future<StoredSession> _refresh(StoredSession current) async {
    try {
      final response = await _post('/auth/otp/refresh', {
        'refreshToken': current.refreshToken,
      });
      final refreshed = StoredSession(
        accountId: current.accountId,
        deviceId: current.deviceId,
        accessToken: response['accessToken']! as String,
        refreshToken: response['refreshToken']! as String,
        accessExpiresAt: DateTime.now().add(
          Duration(seconds: response['accessExpiresInSeconds']! as int),
        ),
        deviceStatus: current.deviceStatus,
      );
      await _sessions.write(refreshed);
      return refreshed;
    } on AuthenticationException catch (error) {
      // A network outage must not sign the user out or discard the refresh
      // token. Only a server-confirmed invalid/replayed session is terminal.
      if (error.code == 'invalid_refresh_session' ||
          error.code == 'refresh_token_reuse_detected') {
        await _sessions.clear();
      }
      rethrow;
    }
  }

  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body, {
    String? bearer,
  }) async {
    final response = await _client
        .post(
          ApiConfig.endpoint(path),
          headers: {
            'content-type': 'application/json',
            if (bearer != null) 'authorization': 'Bearer $bearer',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = decoded is Map ? decoded['message']?.toString() : null;
      throw AuthenticationException(code ?? 'authentication_request_failed');
    }
    if (decoded is! Map<String, Object?>) {
      throw const AuthenticationException('invalid_server_response');
    }
    return decoded;
  }

  Future<String> _developmentRegistrationKey() async {
    final existing = await _sessions.readDevelopmentDeviceKey();
    if (existing != null) return existing;
    // Development registration only. Replace with the public key emitted by the
    // reviewed E2EE SDK before production messaging is enabled.
    final random = Random.secure();
    final generated = base64Encode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await _sessions.writeDevelopmentDeviceKey(generated);
    return generated;
  }

  SessionIdentity _identity(StoredSession session) => SessionIdentity(
    userId: session.accountId,
    deviceId: session.deviceId,
    verification: VerificationStatus.pending,
    deviceStatus: switch (session.deviceStatus) {
      'trusted' => DeviceStatus.trusted,
      'revoked' => DeviceStatus.revoked,
      _ => DeviceStatus.pending,
    },
  );

  String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'web',
    };
  }
}
