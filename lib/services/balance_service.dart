import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/money.dart';

/// A point-in-time snapshot of the user's money state.
class MoneySnapshot {
  final double income;
  final double expense;
  final double spentToday;
  final double dailyBudget;

  const MoneySnapshot({
    required this.income,
    required this.expense,
    required this.spentToday,
    required this.dailyBudget,
  });

  /// Available balance = everything in − everything out.
  /// Locked money and savings-goal contributions are recorded as expense
  /// transactions, so they are already deducted here.
  double get available => income - expense;

  /// True once the user has reached or passed their daily spending limit.
  bool get frozen => dailyBudget > 0 && spentToday >= dailyBudget;
}

/// Central money engine for STASH — the single source of truth for the
/// available balance and the daily-limit "freeze" rule.
///
/// Rules enforced:
///  • Every spend (expense / transfer / airtime / data) must stay within the
///    available balance.
///  • Once the daily spending limit is reached, normal spending is frozen
///    until the next day. Only locking money and adding to savings goals are
///    allowed past the limit (they are savings, not spending).
///  • Locking money and savings-goal contributions still must stay within the
///    available balance.
class BalanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Categories that represent savings (money set aside), not daily spending.
  /// These reduce the available balance but never count toward the daily
  /// spending limit / freeze.
  static const Set<String> savingsCategories = {'Locked Money', 'Savings Goal'};

  static double toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  /// Reads the latest money state from Firestore.
  Future<MoneySnapshot> snapshot() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const MoneySnapshot(
          income: 0, expense: 0, spentToday: 0, dailyBudget: 0);
    }

    final userRef = _db.collection('users').doc(user.uid);

    final txSnap = await userRef.collection('transactions').get();
    double income = 0;
    double expense = 0;
    double spentToday = 0;
    final now = DateTime.now();

    for (final doc in txSnap.docs) {
      final data = doc.data();
      final type = data['type'];
      final amount = toDouble(data['amount']);
      final category = (data['category'] ?? '').toString();
      final date = DateTime.tryParse((data['date'] ?? '').toString());

      if (type == 'income') {
        income += amount;
      } else if (type == 'expense') {
        expense += amount;
        final isSaving = savingsCategories.contains(category);
        if (!isSaving &&
            date != null &&
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day) {
          spentToday += amount;
        }
      }
    }

    double dailyBudget = 0;
    try {
      final userDoc = await userRef.get();
      final ud = userDoc.data();
      if (ud != null && ud['dailyBudget'] != null) {
        dailyBudget = toDouble(ud['dailyBudget']);
      }
    } catch (_) {}

    return MoneySnapshot(
      income: income,
      expense: expense,
      spentToday: spentToday,
      dailyBudget: dailyBudget,
    );
  }

  /// Guard a normal spend (expense / transfer / airtime / data).
  /// Returns an error message if the spend is not allowed, otherwise null.
  Future<String?> guardSpend(double amount) async {
    final snap = await snapshot();
    if (amount > snap.available) {
      return 'Insufficient balance. Your available balance is '
          '${Money.naira(snap.available)}.';
    }
    if (snap.frozen) {
      return 'Daily limit reached. Spending is frozen until tomorrow — only '
          'locking money and savings goals are allowed.';
    }
    return null;
  }

  /// Guard a protected savings action (lock money / savings goal).
  /// Allowed even when the daily limit is reached, but still must stay within
  /// the available balance.
  Future<String?> guardSave(double amount) async {
    final snap = await snapshot();
    if (amount > snap.available) {
      return 'Insufficient balance. Your available balance is '
          '${Money.naira(snap.available)}.';
    }
    return null;
  }
}
