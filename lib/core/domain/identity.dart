enum VerificationStatus { pending, verified, rejected }

enum DeviceStatus { pending, trusted, revoked }

/// Populated by an authenticated identity adapter, never by a profile form.
class SessionIdentity {
  final String userId;
  final String deviceId;
  final VerificationStatus verification;
  final DeviceStatus deviceStatus;
  const SessionIdentity({
    required this.userId,
    required this.deviceId,
    required this.verification,
    required this.deviceStatus,
  });
}

class AccessDenied implements Exception {
  final String code;
  const AccessDenied(this.code);
  @override
  String toString() => 'AccessDenied($code)';
}

void requireTrustedIdentity(SessionIdentity identity) {
  if (identity.userId.trim().isEmpty || identity.deviceId.trim().isEmpty) {
    throw const AccessDenied('missing_identity');
  }
  if (identity.verification != VerificationStatus.verified) {
    throw const AccessDenied('advocate_not_verified');
  }
  if (identity.deviceStatus != DeviceStatus.trusted) {
    throw const AccessDenied('device_not_trusted');
  }
}
