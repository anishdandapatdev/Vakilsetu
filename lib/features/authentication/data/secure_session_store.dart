import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredSession {
  final String accountId;
  final String deviceId;
  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final String deviceStatus;

  const StoredSession({
    required this.accountId,
    required this.deviceId,
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.deviceStatus,
  });

  Map<String, Object?> toJson() => {
    'accountId': accountId,
    'deviceId': deviceId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessExpiresAt': accessExpiresAt.toUtc().toIso8601String(),
    'deviceStatus': deviceStatus,
  };

  factory StoredSession.fromJson(Map<String, Object?> json) => StoredSession(
    accountId: json['accountId']! as String,
    deviceId: json['deviceId']! as String,
    accessToken: json['accessToken']! as String,
    refreshToken: json['refreshToken']! as String,
    accessExpiresAt: DateTime.parse(json['accessExpiresAt']! as String),
    deviceStatus: json['deviceStatus']! as String,
  );
}

class SecureSessionStore {
  static const _sessionKey = 'vakilsetu.auth.session.v1';
  static const _developmentDeviceKey = 'vakilsetu.auth.development-device-key.v1';
  final FlutterSecureStorage _storage;

  const SecureSessionStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  Future<StoredSession?> read() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded == null) return null;
    try {
      return StoredSession.fromJson(jsonDecode(encoded) as Map<String, Object?>);
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> write(StoredSession session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  Future<void> clear() => _storage.delete(key: _sessionKey);

  Future<String?> readDevelopmentDeviceKey() =>
      _storage.read(key: _developmentDeviceKey);

  Future<void> writeDevelopmentDeviceKey(String value) =>
      _storage.write(key: _developmentDeviceKey, value: value);
}
