import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lightweight per-user preferences stored on the user document.
class SettingsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---- Dark mode ----
  Future<void> saveDarkMode(bool isDark) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db
        .collection('users')
        .doc(user.uid)
        .set({'darkMode': isDark}, SetOptions(merge: true));
  }

  Future<bool> loadDarkMode() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return false;
    return (data['darkMode'] as bool?) ?? false;
  }

  // ---- Auto-Save round-ups ----
  Future<void> saveRoundUps(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db
        .collection('users')
        .doc(user.uid)
        .set({'roundUpsEnabled': enabled}, SetOptions(merge: true));
  }

  Future<bool> loadRoundUps() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return false;
    return (data['roundUpsEnabled'] as bool?) ?? false;
  }

  // ---- Push notifications ----
  // Defaults to true: users are opted in until they explicitly turn it off.
  // The Cloud Functions backend reads `notificationsEnabled` and skips sends
  // when it is false.
  Future<void> saveNotifications(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db
        .collection('users')
        .doc(user.uid)
        .set({'notificationsEnabled': enabled}, SetOptions(merge: true));
  }

  Future<bool> loadNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return true;
    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return true;
    return (data['notificationsEnabled'] as bool?) ?? true;
  }
}
