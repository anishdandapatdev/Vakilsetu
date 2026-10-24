import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/domain/identity.dart';
import '../domain/advocate_profile.dart';

class FirebaseProfileRepository implements ProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FlutterSecureStorage _storage;

  static const _localProfileKey = 'firebase_profile_local';

  FirebaseProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FlutterSecureStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? const FlutterSecureStorage();

  User? get currentUser => _auth.currentUser;

  @override
  Future<AdvocateProfile?> getMine() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc =
            await _firestore.collection('advocates').doc(user.uid).get();
        if (doc.exists) {
          final profile = _docToProfile(doc);
          await _saveLocal(profile);
          return profile;
        }

        // Check users collection if not in advocates
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          final profile = AdvocateProfile(
            id: user.uid,
            fullName: data['fullName'] as String? ?? user.displayName ?? 'Advocate',
            enrollmentNumber: data['enrollmentNumber'] as String? ?? 'D/1234/2020',
            primaryCourtId: data['primaryCourtId'] as String? ?? 'delhi_high_court',
            primaryCourtName: 'Delhi High Court',
            practiceAreas: 'General Practice · Civil & Criminal',
            email: user.email,
            verification: VerificationStatus.verified,
          );
          await _saveLocal(profile);
          return profile;
        }
      } catch (e) {
        debugPrint('FirebaseProfileRepository getMine error: $e');
      }
    }

    return _readLocal();
  }

  Stream<AdvocateProfile?> streamMine() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(_readLocalSynchronous());
    }
    return _firestore
        .collection('advocates')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? _docToProfile(doc) : null);
  }

  @override
  Future<AdvocateProfile> save(ProfileUpdate update) async {
    final user = _auth.currentUser;
    final docId = user?.uid ?? 'current_user';

    final courts = await listCourtIdsByName();
    String? courtName;
    for (final entry in courts.entries) {
      if (entry.value == update.primaryCourtId) {
        courtName = entry.key;
        break;
      }
    }
    courtName ??= 'Delhi High Court';

    final profile = AdvocateProfile(
      id: docId,
      fullName: update.fullName,
      enrollmentNumber: update.enrollmentNumber,
      primaryCourtId: update.primaryCourtId,
      primaryCourtName: courtName,
      practiceAreas: update.practiceAreas ?? 'Civil litigation · Commercial',
      bio: update.bio,
      email: user?.email,
      verification: VerificationStatus.verified,
    );

    try {
      final data = {
        'id': docId,
        'fullName': profile.fullName,
        'enrollmentNumber': profile.enrollmentNumber,
        'primaryCourtId': profile.primaryCourtId,
        'primaryCourtName': profile.primaryCourtName,
        'practiceAreas': profile.practiceAreas,
        'bio': profile.bio,
        'isVerified': true,
        'verification': 'verified',
        'email': user?.email,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('advocates').doc(docId).set(data, SetOptions(merge: true));
      await _firestore.collection('users').doc(docId).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving advocate profile: $e');
    }

    await _saveLocal(profile);
    return profile;
  }

  @override
  Future<Map<String, String>> listCourtIdsByName() async {
    try {
      final snapshot = await _firestore.collection('courts').get();
      if (snapshot.docs.isNotEmpty) {
        final map = <String, String>{};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final name = data['name'] as String? ?? doc.id;
          map[name] = doc.id;
        }
        return map;
      }
    } catch (e) {
      debugPrint('Error loading courts: $e');
    }

    return const {
      'Delhi High Court': 'delhi_high_court',
      'Saket District Court': 'saket_district_court',
      'Tis Hazari Courts': 'tis_hazari_courts',
      'Patiala House Courts': 'patiala_house_courts',
      'Karkardooma Courts': 'karkardooma_courts',
      'Rohini District Court': 'rohini_district_court',
    };
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _storage.delete(key: _localProfileKey);
  }

  AdvocateProfile _docToProfile(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final statusStr = (data['verification'] as String? ?? 'verified').toLowerCase();
    final status = switch (statusStr) {
      'verified' => VerificationStatus.verified,
      'rejected' || 'suspended' => VerificationStatus.rejected,
      _ => VerificationStatus.pending,
    };

    return AdvocateProfile(
      id: doc.id,
      fullName: (data['fullName'] as String?) ?? 'Advocate',
      enrollmentNumber: (data['enrollmentNumber'] as String?) ?? '',
      primaryCourtId: (data['primaryCourtId'] as String?) ?? 'delhi_high_court',
      primaryCourtName: (data['primaryCourtName'] ?? data['primaryCourt']) as String?,
      photoKey: data['photoKey'] as String?,
      practiceAreas: data['practiceAreas'] as String?,
      experienceYears: (data['experienceYears'] as num?)?.toInt(),
      bio: data['bio'] as String?,
      email: data['email'] as String?,
      verification: status,
    );
  }

  AdvocateProfile? _readLocalSynchronous() {
    return const AdvocateProfile(
      id: 'local_user',
      fullName: 'Arjun Kumar',
      enrollmentNumber: 'D/3421/2017',
      primaryCourtId: 'delhi_high_court',
      primaryCourtName: 'Delhi High Court',
      practiceAreas: 'Civil Litigation · Corporate Advisory',
      verification: VerificationStatus.verified,
    );
  }

  Future<void> _saveLocal(AdvocateProfile profile) async {
    try {
      await _storage.write(
        key: _localProfileKey,
        value: jsonEncode({
          'id': profile.id,
          'fullName': profile.fullName,
          'enrollmentNumber': profile.enrollmentNumber,
          'primaryCourtId': profile.primaryCourtId,
          'primaryCourtName': profile.primaryCourtName,
          'practiceAreas': profile.practiceAreas,
          'bio': profile.bio,
          'email': profile.email,
          'verification': profile.verification.name,
        }),
      );
    } catch (_) {}
  }

  Future<AdvocateProfile?> _readLocal() async {
    try {
      final raw = await _storage.read(key: _localProfileKey);
      if (raw != null && raw.isNotEmpty) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return AdvocateProfile(
          id: json['id'] as String,
          fullName: json['fullName'] as String,
          enrollmentNumber: json['enrollmentNumber'] as String,
          primaryCourtId: json['primaryCourtId'] as String,
          primaryCourtName: json['primaryCourtName'] as String?,
          practiceAreas: json['practiceAreas'] as String?,
          bio: json['bio'] as String?,
          email: json['email'] as String?,
          verification: VerificationStatus.values.byName(
            json['verification'] as String? ?? 'verified',
          ),
        );
      }
    } catch (_) {}
    return _readLocalSynchronous();
  }
}
