import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/balance_service.dart';
import '../services/lock_service.dart';
import '../services/firestore_service.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import 'widgets/success_dialog.dart';

/// STASH — Lock Money (black liquid UI).
///
/// Pick an amount (tap the ring), a lock duration, and STASH shows the
/// interest rate and the maturity payout. All persistence is preserved:
/// BalanceService().guardSave, LockService().lockMoney, the 'Locked Money'
/// expense record, and the success dialog. Active locks remain viewable below.
class LockMoneyScreen extends StatefulWidget {
  const LockMoneyScreen({super.key});

  @override
  State<LockMoneyScreen> createState() => _LockMoneyScreenState();
}

class _LockMoneyScreenState extends State<LockMoneyScreen> {
  double amount = 0;
  int durationDays = 90;
  bool isLoading = false;

  static const double _minAmount = 100;
  static const double _maxAmount = 10000000;

  // Duration -> annual interest rate (% p.a.).
  static const Map<int, double> _rates = {30: 8, 90: 12, 180: 15};

  double get _rate => _rates[durationDays] ?? 12;

  DateTime get _maturityDate =>
      DateTime.now().add(Duration(days: durationDays));

  double get _payout =>
      amount + (amount * (_rate / 100) * (durationDays / 365));

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  String _slashDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ---- Amount entry sheet (tapping the ring) ----
  void _openAmountSheet() {
    final controller = TextEditingController(
        text: amount > 0 ? amount.toStringAsFixed(0) : '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Amount to lock',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                        fontSize: 20),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.payments_outlined,
                          color: AppColors.primary),
                      hintText: '0',
                      hintStyle: TextStyle(color: AppColors.muted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    onPressed: () {
                      final v = double.tryParse(controller.text.trim()) ?? 0;
                      setState(() => amount = v);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Set amount',
                        style: TextStyle(
                            color: Color(0xFF0A0A0C),
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _lock() async {
    FocusScope.of(context).unfocus();

    if (amount <= 0) {
      _showError('Tap the circle to enter an amount to lock.');
      return;
    }
    if (amount < _minAmount) {
      _showError('Minimum lock amount is ${Money.naira(_minAmount)}.');
      return;
    }
    if (amount > _maxAmount) {
      _showError('Amount is too large. Maximum is ${Money.naira(_maxAmount)}.');
      return;
    }

    final purpose = 'Savings lock ($durationDays days)';
    final unlockDate = _slashDate(_maturityDate);

    setState(() => isLoading = true);

    final guard = await BalanceService().guardSave(amount);
    if (!mounted) return;
    if (guard != null) {
      setState(() => isLoading = false);
      _showError(guard);
      return;
    }

    final error = await LockService().lockMoney(
      amount: amount,
      purpose: purpose,
      unlockDate: unlockDate,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => isLoading = false);
      _showError(error);
      return;
    }

    final transaction = TransactionModel(
      type: 'expense',
      category: 'Locked Money',
      amount: amount,
      note: 'Locked for $durationDays days',
      date: DateTime.now(),
    );
    final transactionError =
        await FirestoreService().addTransaction(transaction);
    if (!mounted) return;
    setState(() => isLoading = false);

    if (transactionError != null) {
      _showError(transactionError);
      return;
    }

    final locked = amount;
    setState(() => amount = 0);

    await completeTransaction(
      context,
      title: 'Money Locked',
      message:
          'You locked ${Money.naira(locked)} for $durationDays days. It matures on ${_shortDate(_maturityDate)}.',
      amount: locked,
      type: 'lock',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: 24),
              Center(child: _ring()),
              const SizedBox(height: 18),
              Center(
                child: Text("Locked funds can't be withdrawn until the date ends",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.muted, height: 1.45, fontSize: 13)),
              ),
              const SizedBox(height: 28),
              Text('Duration',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _durationSelector(),
              const SizedBox(height: 16),
              _infoRow('Interest rate',
                  '${_rate.toStringAsFixed(0)}% p.a.'),
              const SizedBox(height: 12),
              _infoRow("You'll receive on ${_shortDate(_maturityDate)}",
                  Money.naira(_payout)),
              const SizedBox(height: 30),
              Text('Active locks',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              _activeLocks(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _lockBar(),
    );
  }

  // ---- Header ----
  Widget _header(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(Icons.arrow_back_rounded,
                size: 20, color: AppColors.text),
          ),
        ),
        const SizedBox(width: 14),
        Text('Lock money',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
      ],
    );
  }

  // ---- Amount ring ----
  Widget _ring() {
    final progress = (durationDays / 180).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: _openAmountSheet,
      child: SizedBox(
        height: 220,
        width: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 220,
              width: 220,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 16,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(amount > 0 ? Money.naira(amount) : 'Tap to set',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: amount > 0 ? 26 : 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('to lock',
                    style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Duration pills ----
  Widget _durationSelector() {
    Widget pill(int days) {
      final selected = durationDays == days;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => durationDays = days),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.30),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Text('$days days',
                style: TextStyle(
                    color: selected ? AppColors.onAccent : AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
        ),
      );
    }

    return Row(
      children: [pill(30), pill(90), pill(180)],
    );
  }

  // ---- Info row card ----
  Widget _infoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.soft,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Text(value,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
        ],
      ),
    );
  }

  // ---- Active locks ----
  Widget _activeLocks() {
    return StreamBuilder<QuerySnapshot>(
      stream: LockService().getLockedMoney(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadow.soft,
            ),
            child: Text('Could not load your locks.',
                style: TextStyle(color: AppColors.muted)),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadow.soft,
            ),
            child: Text('No locked funds yet.',
                style: TextStyle(color: AppColors.muted)),
          );
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            final amt = (data?['amount'] is num)
                ? (data!['amount'] as num).toDouble()
                : 0.0;
            final purpose = (data?['purpose'] as String?) ?? 'Locked';
            final unlockDate = (data?['unlockDate'] as String?) ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadow.soft,
              ),
              child: Row(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(purpose,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.text)),
                        const SizedBox(height: 4),
                        Text('Unlocks: $unlockDate',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(Money.naira(amt),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.text)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ---- Lock button ----
  Widget _lockBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.7),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          onPressed: isLoading ? null : _lock,
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Color(0xFF0A0A0C)))
              : Text(
                  amount > 0
                      ? 'Lock ${Money.naira(amount)}'
                      : 'Enter amount to lock',
                  style: const TextStyle(
                      color: Color(0xFF0A0A0C),
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}
