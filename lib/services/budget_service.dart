import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BudgetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> saveBudget({
    required double balance,
    required int days,
    required double dailyBudget,
  }) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return 'You are not logged in.';
      }

      await _db.collection('users').doc(user.uid).set({
        'budgetBalance': balance,
        'budgetDays': days,
        'dailyBudget': dailyBudget,
      }, SetOptions(merge: true));

      return null;
    } catch (_) {
      return 'Could not save budget. Check your connection and try again.';
    }
  }

  Stream<DocumentSnapshot> getBudget() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<DocumentSnapshot>.empty();
    }

    return _db.collection('users').doc(user.uid).snapshots();
  }
}
