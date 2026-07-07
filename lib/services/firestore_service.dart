import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> addTransaction(TransactionModel transaction) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return 'You are not logged in.';
      }

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .add(transaction.toMap());

      return null;
    } catch (_) {
      return 'Could not save transaction. Check your connection and try again.';
    }
  }

  Stream<QuerySnapshot> getTransactions() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }
}
