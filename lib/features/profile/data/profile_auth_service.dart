import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/advocate_profile.dart';
import 'firebase_profile_repository.dart';

/// Manages advocate profile authentication, session state, and Firestore synchronization.
class ProfileAuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseProfileRepository _profileRepo;

  ProfileAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseProfileRepository? profileRepository,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _profileRepo = profileRepository ?? FirebaseProfileRepository();

  User? get currentUser => _auth.currentUser;

  bool get isAuthenticated => _auth.currentUser != null && !_auth.currentUser!.isAnonymous;

  bool get isGuest => _auth.currentUser != null && _auth.currentUser!.isAnonymous;

  String get currentUid => _auth.currentUser?.uid ?? 'guest_local';

  String get currentEmail =>
      _auth.currentUser?.email ?? (isGuest ? 'Guest Session' : 'Not signed in');

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password.
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
      final user = credential.user!;
      await _syncUserRecord(user);
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials') {
        // If account does not exist, automatically register new advocate
        return await registerWithEmail(
          email: cleanEmail,
          password: cleanPassword,
        );
      }
      throw _parseAuthException(e);
    }
  }

  /// Register a new advocate with email and password.
  Future<User> registerWithEmail({
    required String email,
    required String password,
    String? fullName,
    String? enrollmentNumber,
    String? primaryCourtId,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
      final user = credential.user!;

      // Create user record in Firestore
      await _syncUserRecord(
        user,
        fullName: fullName,
        enrollmentNumber: enrollmentNumber,
        primaryCourtId: primaryCourtId,
      );

      return user;
    } on FirebaseAuthException catch (e) {
      throw _parseAuthException(e);
    }
  }

  /// Sign in anonymously for preview / guest access.
  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user!;
      await _syncUserRecord(user);
      return user;
    } catch (e) {
      debugPrint('Anonymous auth failed (may be disabled in console): $e');
      return null;
    }
  }

  /// Sign out from Firebase and clear local profile cache.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
    await _profileRepo.signOut();
  }

  /// Get current advocate profile.
  Future<AdvocateProfile?> getProfile() => _profileRepo.getMine();

  /// Stream current advocate profile changes in real time.
  Stream<AdvocateProfile?> streamProfile() => _profileRepo.streamMine();

  /// Update and save advocate profile to Firestore.
  Future<AdvocateProfile> updateProfile(ProfileUpdate update) =>
      _profileRepo.save(update);

  Future<void> _syncUserRecord(
    User user, {
    String? fullName,
    String? enrollmentNumber,
    String? primaryCourtId,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final advocateRef = _firestore.collection('advocates').doc(user.uid);

      final userData = <String, dynamic>{
        'id': user.uid,
        'email': user.email ?? 'advocate_${user.uid.substring(0, 6)}@vakilsetu.in',
        'isVerified': true,
        'verification': 'verified',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (fullName != null && fullName.isNotEmpty) userData['fullName'] = fullName;
      if (enrollmentNumber != null && enrollmentNumber.isNotEmpty) {
        userData['enrollmentNumber'] = enrollmentNumber;
      }
      if (primaryCourtId != null && primaryCourtId.isNotEmpty) {
        userData['primaryCourtId'] = primaryCourtId;
      }

      await userRef.set(userData, SetOptions(merge: true));

      // Also ensure advocate directory record exists
      final advocateDoc = await advocateRef.get();
      if (!advocateDoc.exists) {
        await advocateRef.set({
          'id': user.uid,
          'fullName': fullName ?? user.displayName ?? 'Advocate ${user.email?.split('@').first ?? ""}'.trim(),
          'enrollmentNumber': enrollmentNumber ?? 'D/2026/${user.uid.substring(0, 4).toUpperCase()}',
          'primaryCourtId': primaryCourtId ?? 'delhi_high_court',
          'primaryCourtName': 'Delhi High Court',
          'practiceAreas': 'Civil Litigation · Corporate Advisory',
          'bio': 'Advocate practicing at Delhi High Court and District Courts.',
          'email': user.email,
          'isVerified': true,
          'verification': 'verified',
          'experienceYears': 5,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error syncing user record: $e');
    }
  }

  String _parseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please provide a valid email address.';
      case 'user-disabled':
        return 'This advocate account has been disabled.';
      case 'wrong-password':
        return 'Incorrect password. Please verify and try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address. Please sign in.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase Console.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
