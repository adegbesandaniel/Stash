import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> lockMoney({
    required double amount,
    required String purpose,
    required String unlockDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return 'You are not logged in.';
    }

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('locked_money')
          .add({
        'amount': amount,
        'purpose': purpose,
        'unlockDate': unlockDate,
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'locked',
      });

      return null;
    } catch (e) {
      return 'Could not lock money. Check your connection and try again.';
    }
  }

  Stream<QuerySnapshot> getLockedMoney() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('locked_money')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
