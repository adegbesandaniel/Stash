import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';

/// Handles the STASH app lock: a 4-digit PIN (stored only as a salted SHA-256
/// hash) plus optional biometric unlock via the device's fingerprint / face.
class SecurityService {
  /// True once the user has unlocked during this app session, so we don't
  /// prompt repeatedly while navigating.
  static bool unlockedThisSession = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Rejects trivially guessable PINs (all-same digits, simple sequences).
  static bool isWeakPin(String pin) {
    if (pin.length != 4) return false;
    if (pin.split('').toSet().length == 1) return true; // e.g. 0000, 1111
    const ascending = '0123456789';
    const descending = '9876543210';
    return ascending.contains(pin) || descending.contains(pin);
  }

  String _hash(String pin, String uid) {
    final bytes = utf8.encode('stash::$uid::$pin');
    return sha256.convert(bytes).toString();
  }

  Future<Map<String, dynamic>?> _userData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  Future<bool> isAppLockEnabled() async {
    final data = await _userData();
    if (data == null) return false;
    return (data['appLockEnabled'] as bool?) ?? false;
  }

  Future<bool> hasPin() async {
    final data = await _userData();
    return data != null && data['pinHash'] != null;
  }

  Future<String?> setPin(String pin) async {
    final user = _auth.currentUser;
    if (user == null) return 'You are not logged in.';
    if (pin.length != 4) return 'Your PIN must be 4 digits.';
    if (isWeakPin(pin)) return 'Choose a less predictable PIN.';

    try {
      await _db.collection('users').doc(user.uid).set({
        'pinHash': _hash(pin, user.uid),
        'appLockEnabled': true,
      }, SetOptions(merge: true));
      unlockedThisSession = true;
      return null;
    } catch (_) {
      return 'Could not save your PIN. Check your connection and try again.';
    }
  }

  Future<bool> verifyPin(String pin) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final data = await _userData();
    if (data == null || data['pinHash'] == null) return false;
    return data['pinHash'] == _hash(pin, user.uid);
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .set({'appLockEnabled': enabled}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<bool> isBiometricEnabled() async {
    final data = await _userData();
    if (data == null) return false;
    return (data['biometricEnabled'] as bool?) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .set({'biometricEnabled': enabled}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final enrolled = await _localAuth.getAvailableBiometrics();
      return supported && canCheck && enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock STASH',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
