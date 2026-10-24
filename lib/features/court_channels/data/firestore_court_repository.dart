import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/court_repository.dart';

class FirestoreCourtRepository implements CourtRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FlutterSecureStorage _storage;

  static const _localJoinedKey = 'firestore_joined_court_ids';
  bool _seeded = false;

  FirestoreCourtRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FlutterSecureStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<List<CourtChannel>> listCourts() async {
    try {
      final snapshot = await _firestore
          .collection('courts')
          .orderBy('order')
          .get();

      if (snapshot.docs.isEmpty && !_seeded) {
        _seeded = true;
        await _seedInitialCourts();
        final refreshed = await _firestore
            .collection('courts')
            .orderBy('order')
            .get();
        return refreshed.docs.map(_docToCourtChannel).toList(growable: false);
      }

      return snapshot.docs.map(_docToCourtChannel).toList(growable: false);
    } catch (e) {
      debugPrint('Firestore listCourts error: $e');
      // If Firestore fails or rules restrict, fallback to default courts
      return _defaultCourts;
    }
  }

  CourtChannel _docToCourtChannel(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CourtChannel(
      id: doc.id,
      channelId: (data['channelId'] as String?) ?? doc.id,
      name: (data['name'] as String?) ?? doc.id,
      city: (data['city'] as String?) ?? 'New Delhi',
      imageKey: data['imageKey'] as String?,
    );
  }

  @override
  Future<Set<String>> joinedCourtIds() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          final list = data?['joinedCourtIds'] as List<dynamic>?;
          if (list != null) {
            final set = list.map((e) => e.toString()).toSet();
            await _saveLocalJoined(set);
            return set;
          }
        }
      } catch (e) {
        debugPrint('Firestore joinedCourtIds fetch error: $e');
      }
    }

    return _readLocalJoined();
  }

  @override
  Future<void> setJoined(String courtId, bool joined) async {
    final current = await _readLocalJoined();
    if (joined) {
      current.add(courtId);
    } else {
      current.remove(courtId);
    }
    await _saveLocalJoined(current);

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set(
          {
            'joinedCourtIds': joined
                ? FieldValue.arrayUnion([courtId])
                : FieldValue.arrayRemove([courtId]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // Also track member count on court document
        await _firestore.collection('courts').doc(courtId).set(
          {
            'membersCount': FieldValue.increment(joined ? 1 : -1),
          },
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('Firestore setJoined error: $e');
      }
    }
  }

  @override
  Future<List<CourtAnnouncement>> announcements(String channelId) async {
    try {
      final snapshot = await _firestore
          .collection('courts')
          .doc(channelId)
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        // Check if sample announcements can be added for this channel
        await _seedAnnouncementsForCourt(channelId);
        final refreshed = await _firestore
            .collection('courts')
            .doc(channelId)
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .get();
        return refreshed.docs.map(_docToAnnouncement).toList(growable: false);
      }

      return snapshot.docs.map(_docToAnnouncement).toList(growable: false);
    } catch (e) {
      debugPrint('Firestore announcements error: $e');
      return [];
    }
  }

  @override
  Stream<List<CourtAnnouncement>> streamAnnouncements(String channelId) {
    return _firestore
        .collection('courts')
        .doc(channelId)
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_docToAnnouncement).toList());
  }

  @override
  Future<void> postAnnouncement({
    required String channelId,
    required String title,
    required String body,
    String? attachmentKey,
  }) async {
    final user = _auth.currentUser;
    await _firestore
        .collection('courts')
        .doc(channelId)
        .collection('announcements')
        .add({
      'title': title,
      'body': body,
      'attachmentKey': attachmentKey,
      'revision': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'authorId': user?.uid,
      'authorName': user?.displayName ?? 'Court Registry',
    });
  }

  CourtAnnouncement _docToAnnouncement(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    DateTime createdAt = DateTime.now();
    final rawDate = data['createdAt'];
    if (rawDate is Timestamp) {
      createdAt = rawDate.toDate();
    } else if (rawDate is String) {
      createdAt = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return CourtAnnouncement(
      id: doc.id,
      title: data['title'] as String?,
      body: (data['body'] as String?) ?? '',
      attachmentKey: data['attachmentKey'] as String?,
      revision: (data['revision'] as num?)?.toInt() ?? 1,
      createdAt: createdAt,
    );
  }

  Future<Set<String>> _readLocalJoined() async {
    try {
      final raw = await _storage.read(key: _localJoinedKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return {'delhi_high_court', 'saket_district_court'};
  }

  Future<void> _saveLocalJoined(Set<String> set) async {
    try {
      await _storage.write(
        key: _localJoinedKey,
        value: jsonEncode(set.toList()),
      );
    } catch (_) {}
  }

  static const _defaultCourts = [
    CourtChannel(
      id: 'delhi_high_court',
      channelId: 'delhi_high_court',
      name: 'Delhi High Court',
      city: 'New Delhi',
      imageKey: 'assets/images/courts/delhi_high_court_list.png',
    ),
    CourtChannel(
      id: 'saket_district_court',
      channelId: 'saket_district_court',
      name: 'Saket District Court',
      city: 'South Delhi',
      imageKey: 'assets/images/courts/saket_district_court_list.png',
    ),
    CourtChannel(
      id: 'tis_hazari_courts',
      channelId: 'tis_hazari_courts',
      name: 'Tis Hazari Courts',
      city: 'Central Delhi',
      imageKey: 'assets/images/courts/tis_hazari_courts.png',
    ),
    CourtChannel(
      id: 'patiala_house_courts',
      channelId: 'patiala_house_courts',
      name: 'Patiala House Courts',
      city: 'New Delhi',
      imageKey: 'assets/images/courts/patiala_house_courts.png',
    ),
    CourtChannel(
      id: 'karkardooma_courts',
      channelId: 'karkardooma_courts',
      name: 'Karkardooma Courts',
      city: 'East Delhi',
      imageKey: 'assets/images/courts/delhi_high_court.png',
    ),
    CourtChannel(
      id: 'rohini_district_court',
      channelId: 'rohini_district_court',
      name: 'Rohini District Court',
      city: 'North West Delhi',
      imageKey: 'assets/images/courts/saket_district_court.png',
    ),
  ];

  Future<void> _seedInitialCourts() async {
    final batch = _firestore.batch();
    for (int i = 0; i < _defaultCourts.length; i++) {
      final court = _defaultCourts[i];
      final docRef = _firestore.collection('courts').doc(court.id);
      batch.set(docRef, {
        'id': court.id,
        'channelId': court.channelId,
        'name': court.name,
        'city': court.city,
        'imageKey': court.imageKey,
        'order': i + 1,
        'isVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    for (final court in _defaultCourts) {
      await _seedAnnouncementsForCourt(court.id);
    }
  }

  Future<void> _seedAnnouncementsForCourt(String courtId) async {
    final coll = _firestore
        .collection('courts')
        .doc(courtId)
        .collection('announcements');

    final existing = await coll.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    if (courtId == 'delhi_high_court') {
      await coll.add({
        'title': 'Roster of Sitting Judges - Winter Session',
        'body':
            'The revised roster for sitting Division Benches and Single Benches has been notified by the registry. Check cause list for courtroom allocations.',
        'attachmentKey': 'Roster_Sitting_Judges.pdf',
        'revision': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'authorName': 'High Court Registry',
      });
      await coll.add({
        'title': 'Daily Cause List - Court No. 1',
        'body':
            'Urgent admission matters listed before the Hon\'ble Chief Justice Bench. Hybrid hearings begin at 10:30 AM in Court Room 1.',
        'attachmentKey': 'Cause_list.pdf',
        'revision': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'authorName': 'High Court Registry',
      });
    } else if (courtId == 'saket_district_court') {
      await coll.add({
        'title': 'E-Filing Portal Maintenance',
        'body':
            'The district court e-filing facility will undergo scheduled server updates from 8:00 PM to 11:00 PM this Saturday.',
        'attachmentKey': null,
        'revision': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'authorName': 'District Court Administration',
      });
      await coll.add({
        'title': 'Court Room Reallocation Notice',
        'body':
            'Court No. 304 presided by ADJ-02 is temporarily shifted to 4th Floor Room 412 due to renovation work.',
        'attachmentKey': 'Relocation_Notice.pdf',
        'revision': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'authorName': 'Principal District Judge Secretariat',
      });
    } else {
      await coll.add({
        'title': 'National Lok Adalat Schedule',
        'body':
            'Special benches for pre-litigation and pending compoundable matters will convene on the upcoming second Saturday.',
        'attachmentKey': 'Lok_Adalat_Notice.pdf',
        'revision': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'authorName': 'Legal Services Authority',
      });
    }
  }
}
