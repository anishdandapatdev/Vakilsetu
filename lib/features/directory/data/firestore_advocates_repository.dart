import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/domain/identity.dart';
import '../../profile/domain/advocate_profile.dart';
import '../domain/directory_repository.dart';

/// Production repository for advocate profiles and directory search backed by Firestore.
class FirestoreAdvocatesRepository
    implements DirectoryRepository, ProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FlutterSecureStorage _storage;

  static const _localProfileKey = 'firestore_local_advocate_profile';

  FirestoreAdvocatesRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FlutterSecureStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<AdvocatePage> search({
    required String query,
    String? courtId,
    String? cursor,
  }) async {
    try {
      Query<Map<String, dynamic>> ref = _firestore.collection('advocates');

      if (courtId != null && courtId.isNotEmpty && courtId != 'All courts') {
        ref = ref.where('primaryCourtId', isEqualTo: courtId);
      }

      final snapshot = await ref.get();
      final items = _filterAndMap(snapshot.docs, query);
      return AdvocatePage(items, null);
    } catch (e) {
      debugPrint('Firestore search error: $e');
      return AdvocatePage(const [], null);
    }
  }

  List<AdvocateProfile> _filterAndMap(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String query,
  ) {
    final cleanQuery = query.trim().toLowerCase();
    final list = <AdvocateProfile>[];
    final seen = <String>{};

    for (final doc in docs) {
      final profile = _docToProfile(doc);
      final normId = profile.id.toLowerCase().startsWith('adv_')
          ? profile.id.toLowerCase().substring(4)
          : profile.id.toLowerCase();
      final key = normId.isNotEmpty
          ? normId
          : (profile.enrollmentNumber.isNotEmpty
              ? profile.enrollmentNumber.trim().toLowerCase()
              : profile.fullName.trim().toLowerCase());
      if (seen.contains(key)) continue;

      if (cleanQuery.isEmpty) {
        seen.add(key);
        list.add(profile);
      } else {
        final matches = profile.fullName.toLowerCase().contains(cleanQuery) ||
            profile.enrollmentNumber.toLowerCase().contains(cleanQuery) ||
            (profile.primaryCourtName ?? '')
                .toLowerCase()
                .contains(cleanQuery) ||
            (profile.practiceAreas ?? '').toLowerCase().contains(cleanQuery);
        if (matches) {
          seen.add(key);
          list.add(profile);
        }
      }
    }
    return list;
  }

  @override
  Future<AdvocateProfile?> getMine() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc =
            await _firestore.collection('advocates').doc(user.uid).get();
        if (doc.exists) {
          final profile = _docToProfile(doc);
          await _saveLocalProfile(profile);
          return profile;
        }

        // Try user.uid in users collection
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          final profile = AdvocateProfile(
            id: user.uid,
            fullName: data['fullName'] as String? ?? user.displayName ?? 'Advocate',
            enrollmentNumber: (data['enrollmentNumber'] as String?) ?? '',
            primaryCourtId: (data['primaryCourtId'] as String?) ?? 'delhi_high_court',
            primaryCourtName: 'Delhi High Court',
            practiceAreas: data['practiceAreas'] as String? ?? 'General Practice',
            verification: VerificationStatus.verified,
            email: user.email,
          );
          await _saveLocalProfile(profile);
          return profile;
        }
      } catch (e) {
        debugPrint('Firestore getMine error: $e');
      }
    }
    return _readLocalProfile();
  }

  @override
  Future<AdvocateProfile> save(ProfileUpdate update) async {
    final user = _auth.currentUser;
    final docId = user?.uid ?? 'current_user';

    final courtsMap = await listCourtIdsByName();
    String? courtName;
    for (final entry in courtsMap.entries) {
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
      practiceAreas: update.practiceAreas ?? 'General practice',
      bio: update.bio,
      verification: VerificationStatus.verified,
    );

    try {
      await _firestore.collection('advocates').doc(docId).set(
        {
          'id': docId,
          'fullName': profile.fullName,
          'enrollmentNumber': profile.enrollmentNumber,
          'primaryCourtId': profile.primaryCourtId,
          'primaryCourtName': profile.primaryCourtName,
          'practiceAreas': profile.practiceAreas,
          'bio': profile.bio,
          'verification': 'verified',
          'isVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _firestore.collection('users').doc(docId).set(
        {
          'fullName': profile.fullName,
          'enrollmentNumber': profile.enrollmentNumber,
          'primaryCourtId': profile.primaryCourtId,
          'isVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Firestore save profile error: $e');
    }

    await _saveLocalProfile(profile);
    return profile;
  }

  @override
  Future<Map<String, String>> listCourtIdsByName() async {
    try {
      final snapshot = await _firestore.collection('courts').get();
      final map = <String, String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? doc.id;
        final channelId = data['channelId'] as String? ?? doc.id;
        map[name] = channelId;
      }
      return map;
    } catch (e) {
      debugPrint('Firestore listCourtIdsByName error: $e');
      return const {
        'Delhi High Court': 'delhi_high_court',
        'Saket District Court': 'saket_district_court',
        'Tis Hazari Courts': 'tis_hazari_courts',
        'Patiala House Courts': 'patiala_house_courts',
        'Karkardooma Courts': 'karkardooma_courts',
        'Rohini District Court': 'rohini_district_court',
      };
    }
  }

  Stream<List<AdvocateProfile>> streamAdvocates({String? courtId}) {
    Query<Map<String, dynamic>> ref = _firestore.collection('advocates');
    if (courtId != null && courtId.isNotEmpty && courtId != 'All courts') {
      ref = ref.where('primaryCourtId', isEqualTo: courtId);
    }
    return ref.snapshots().map(
          (snapshot) => snapshot.docs.map(_docToProfile).toList(),
        );
  }

  AdvocateProfile _docToProfile(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final statusStr =
        (data['verification'] as String? ?? 'verified').toLowerCase();
    final status = switch (statusStr) {
      'verified' => VerificationStatus.verified,
      'rejected' || 'suspended' => VerificationStatus.rejected,
      _ => VerificationStatus.pending,
    };

    return AdvocateProfile(
      id: doc.id,
      fullName: (data['fullName'] as String?) ?? 'Advocate',
      enrollmentNumber: (data['enrollmentNumber'] as String?) ?? '',
      primaryCourtId: (data['primaryCourtId'] as String?) ?? '',
      primaryCourtName: (data['primaryCourtName'] ?? data['primaryCourt']) as String?,
      photoKey: data['photoKey'] as String?,
      verification: status,
      practiceAreas: data['practiceAreas'] as String?,
      experienceYears: (data['experienceYears'] as num?)?.toInt(),
      bio: data['bio'] as String?,
      email: data['email'] as String?,
    );
  }

  Future<void> _saveLocalProfile(AdvocateProfile profile) async {
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
          'verification': profile.verification.name,
        }),
      );
    } catch (_) {}
  }

  Future<AdvocateProfile?> _readLocalProfile() async {
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
          verification: VerificationStatus.values.byName(
            json['verification'] as String? ?? 'verified',
          ),
        );
      }
    } catch (_) {}
    return null;
  }
}
