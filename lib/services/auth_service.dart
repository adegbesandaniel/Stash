import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// The currently signed-in user (or null if signed out).
  User? get currentUser => _auth.currentUser;

  /// Emits whenever the user signs in or out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = userCredential.user!.uid;
      await userCredential.user!.updateDisplayName(name.trim());

      await _db.collection('users').doc(uid).set({
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Sends a password-reset email. Returns null on success or a message.
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> logout() async {
    // Remove this device's push token first so the user stops receiving
    // notifications for this account on this device after signing out.
    await NotificationService.instance.removeCurrentToken();
    await _auth.signOut();
  }

  /// Converts Firebase error codes into friendly, user-facing messages.
  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again in a moment.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      case 'operation-not-allowed':
        return 'Email sign-in is not enabled. Contact support.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
