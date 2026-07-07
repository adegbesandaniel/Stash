import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> createGoal({
    required String title,
    required double target,
    required String icon,
    String? targetDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return 'You are not logged in.';

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .add({
        'title': title,
        'icon': icon,
        'target': target,
        'saved': 0.0,
        'targetDate': targetDate,
        'createdAt': DateTime.now().toIso8601String(),
      });

      return null;
    } catch (_) {
      return 'Could not create goal. Check your connection and try again.';
    }
  }

  /// Add money to a goal (atomic increment).
  Future<String?> addFunds(String goalId, double amount) async {
    final user = _auth.currentUser;
    if (user == null) return 'You are not logged in.';
    if (amount <= 0) return 'Enter a valid amount greater than zero.';

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .doc(goalId)
          .update({'saved': FieldValue.increment(amount)});

      return null;
    } catch (_) {
      return 'Could not add money. Check your connection and try again.';
    }
  }

  /// Sweep an auto-save round-up into a dedicated "Round-ups" vault.
  /// Uses a deterministic doc id so all round-ups accumulate in one goal.
  Future<String?> addRoundUp(double amount) async {
    final user = _auth.currentUser;
    if (user == null) return 'You are not logged in.';
    if (amount <= 0) return null;

    try {
      final ref = _db
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .doc('roundups');

      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'title': 'Round-ups',
          'icon': '\ud83e\ude99',
          'target': 50000.0,
          'saved': amount,
          'targetDate': null,
          'createdAt': DateTime.now().toIso8601String(),
        });
      } else {
        await ref.update({'saved': FieldValue.increment(amount)});
      }
      return null;
    } catch (_) {
      return 'Could not save round-up. Check your connection and try again.';
    }
  }

  Future<String?> deleteGoal(String goalId) async {
    final user = _auth.currentUser;
    if (user == null) return 'You are not logged in.';

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .doc(goalId)
          .delete();

      return null;
    } catch (_) {
      return 'Could not delete goal. Check your connection and try again.';
    }
  }

  Stream<QuerySnapshot> getGoals() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
