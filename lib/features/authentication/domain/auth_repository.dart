import '../../../core/domain/identity.dart';

abstract interface class AuthRepository {
  /// The server rate-limits attempts and returns an opaque challenge ID.
  Future<String> requestOtp(String phoneNumber);
  Future<SessionIdentity> verifyOtp(String challengeId, String code);
  Future<SessionIdentity> signInWithEmail(String email, String password);
  Future<SessionIdentity?> restoreSession();

  /// Account authentication does not grant access to earlier encryption keys.
  Future<void> signOut();
  Future<void> revokeDevice(String deviceId);
}
