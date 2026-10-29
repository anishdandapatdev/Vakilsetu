import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/court_repository.dart';

/// Production repository for court channels and official circulars stored in Firestore.
class FirestoreCourtRepository implements CourtRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FlutterSecureStorage _storage;

  static const _localJoinedKey = 'firestore_joined_court_ids';

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
      var snapshot = await _firestore
          .collection('courts')
          .orderBy('order')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map(_docToCourtChannel).toList(growable: false);
      }

      // Fallback query without orderBy('order') in case the order field is missing on some docs
      snapshot = await _firestore.collection('courts').get();
      return snapshot.docs.map(_docToCourtChannel).toList(growable: false);
    } catch (e) {
      debugPrint('Firestore listCourts error: $e');
      try {
        final fallback = await _firestore.collection('courts').get();
        return fallback.docs.map(_docToCourtChannel).toList(growable: false);
      } catch (_) {
        return const [];
      }
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

      return snapshot.docs.map(_docToAnnouncement).toList(growable: false);
    } catch (e) {
      debugPrint('Firestore announcements error: $e');
      return const [];
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
    return const {'delhi_high_court'};
  }

  Future<void> _saveLocalJoined(Set<String> set) async {
    try {
      await _storage.write(
        key: _localJoinedKey,
        value: jsonEncode(set.toList()),
      );
    } catch (_) {}
  }
}
