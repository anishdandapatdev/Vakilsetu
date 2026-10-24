import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/domain/identity.dart';
import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<SessionIdentity> signInWithEmail(String email, String password) async {
    final cleanEmail = email.trim();
    UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials') {
        // Try creating account if not found
        try {
          credential = await _auth.createUserWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
        } catch (createError) {
          if (createError is FirebaseAuthException) {
            throw Exception(createError.message ?? 'Authentication failed');
          }
          throw Exception(e.message ?? 'Authentication failed');
        }
      } else {
        throw Exception(e.message ?? 'Authentication failed');
      }
    }

    final user = credential.user!;
    await _syncUserDoc(user);

    return SessionIdentity(
      userId: user.uid,
      deviceId: 'mobile_${user.uid.substring(0, 6)}',
      verification: VerificationStatus.verified,
      deviceStatus: DeviceStatus.trusted,
    );
  }

  Future<SessionIdentity> registerWithEmail(String email, String password) async {
    final cleanEmail = email.trim();
    final credential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );
    final user = credential.user!;
    await _syncUserDoc(user);

    return SessionIdentity(
      userId: user.uid,
      deviceId: 'mobile_${user.uid.substring(0, 6)}',
      verification: VerificationStatus.verified,
      deviceStatus: DeviceStatus.trusted,
    );
  }

  Future<SessionIdentity> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    final user = credential.user!;
    await _syncUserDoc(user);

    return SessionIdentity(
      userId: user.uid,
      deviceId: 'guest_${user.uid.substring(0, 6)}',
      verification: VerificationStatus.verified,
      deviceStatus: DeviceStatus.trusted,
    );
  }

  @override
  Future<SessionIdentity?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    return SessionIdentity(
      userId: user.uid,
      deviceId: 'device_${user.uid.substring(0, 6)}',
      verification: VerificationStatus.verified,
      deviceStatus: DeviceStatus.trusted,
    );
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<String> requestOtp(String phoneNumber) async {
    // Phone OTP was excluded by user requirement; fallback challenge ID
    return 'demo_otp_challenge';
  }

  @override
  Future<SessionIdentity> verifyOtp(String challengeId, String code) async {
    // Demo / fallback verification
    var user = _auth.currentUser;
    if (user == null) {
      final credential = await _auth.signInAnonymously();
      user = credential.user;
    }
    return SessionIdentity(
      userId: user?.uid ?? 'demo_user',
      deviceId: 'device_demo',
      verification: VerificationStatus.verified,
      deviceStatus: DeviceStatus.trusted,
    );
  }

  @override
  Future<void> revokeDevice(String deviceId) async {
    debugPrint('Device revocation requested for $deviceId');
  }

  Future<void> _syncUserDoc(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'email': user.email ?? 'guest_${user.uid.substring(0, 6)}@vakilsetu.in',
          'isVerified': true,
          'createdAt': FieldValue.serverTimestamp(),
          'joinedCourtIds': ['delhi_high_court', 'saket_district_court'],
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error syncing user document: $e');
    }
  }
}
