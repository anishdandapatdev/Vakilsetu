import '../../../core/domain/identity.dart';

class AdvocateProfile {
  final String id;
  final String fullName;
  final String enrollmentNumber;
  final String primaryCourtId;
  final String? primaryCourtName;
  final String? photoKey;
  final VerificationStatus verification;
  final String? practiceAreas;
  final int? experienceYears;
  final String? bio;
  final String? email;

  const AdvocateProfile({
    required this.id,
    required this.fullName,
    required this.enrollmentNumber,
    required this.primaryCourtId,
    this.primaryCourtName,
    this.photoKey,
    required this.verification,
    this.practiceAreas,
    this.experienceYears,
    this.bio,
    this.email,
  });

  bool get showVerifiedBadge => verification == VerificationStatus.verified;
}

abstract interface class ProfileRepository {
  Future<AdvocateProfile?> getMine();
  Future<AdvocateProfile> save(ProfileUpdate update);
  Future<Map<String, String>> listCourtIdsByName();
}

/// Only these fields may be submitted from the profile editor.
/// Approval status, roles and user ID are deliberately not writable here.
class ProfileUpdate {
  final String fullName;
  final String enrollmentNumber;
  final String primaryCourtId;
  final String? practiceAreas;
  final String? bio;

  const ProfileUpdate({
    required this.fullName,
    required this.enrollmentNumber,
    required this.primaryCourtId,
    this.practiceAreas,
    this.bio,
  });
}
