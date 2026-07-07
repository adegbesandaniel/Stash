import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

/// STASH — Virtual Card (black liquid UI).
///
/// Card preview + card controls (freeze, online payments, ATM withdrawals)
/// and a "View card details" reveal. Balance and account number come from
/// the live Firestore streams (logic unchanged).
class VirtualCardScreen extends StatefulWidget {
  const VirtualCardScreen({super.key});

  @override
  State<VirtualCardScreen> createState() => _VirtualCardScreenState();
}

class _VirtualCardScreenState extends State<VirtualCardScreen> {
  bool hideCardDetails = true;
  bool isFrozen = false;
  bool onlinePayments = true;
  bool atmWithdrawals = false;

  static const String _cardNumber = '5421 8832 1090 8830';
  static const String _cardMasked = '5421 •••• •••• 8830';
  static const String _cardExp = '09/29';
  static const String _cardCvv = '334';

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String formatAccountNumber(String uid) {
    final numbers = uid.hashCode.abs().toString().padRight(10, '0');
    return numbers.substring(0, 10);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _toggleFreeze(bool value) {
    setState(() {
      isFrozen = value;
      if (isFrozen) hideCardDetails = true;
    });
    _snack(isFrozen ? 'Card frozen. Unfreeze to use it.' : 'Card unfrozen.');
  }

  void _toggleDetails() {
    if (isFrozen) {
      _snack('Unfreeze the card to view details.');
      return;
    }
    setState(() => hideCardDetails = !hideCardDetails);
  }

  Future<void> _copyAccountNumber(String accountNumber) async {
    await Clipboard.setData(ClipboardData(text: accountNumber));
    if (!mounted) return;
    _snack('Account number copied');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: user == null
            ? Center(
                child: Text('You are not logged in.',
                    style: TextStyle(color: AppColors.muted)))
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  String name = 'STASH User';
                  String school = 'Student';

                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>?;
                  if (userData != null) {
                    name = (userData['name'] as String?)?.trim().isNotEmpty ==
                            true
                        ? userData['name'] as String
                        : 'STASH User';
                    school = (userData['school'] as String?)
                                ?.trim()
                                .isNotEmpty ==
                            true
                        ? userData['school'] as String
                        : 'Student';
                  }

                  final accountNumber = formatAccountNumber(user.uid);

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirestoreService().getTransactions(),
                    builder: (context, transactionSnapshot) {
                      final hasError = transactionSnapshot.hasError;
                      final isLoadingTx = transactionSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !transactionSnapshot.hasData;

                      double totalIncome = 0;
                      double totalExpense = 0;

                      if (transactionSnapshot.hasData) {
                        for (final doc in transactionSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>?;
                          if (data == null) continue;
                          final type = data['type'];
                          final amount = _toDouble(data['amount']);
                          if (type == 'income') {
                            totalIncome += amount;
                          } else if (type == 'expense') {
                            totalExpense += amount;
                          }
                        }
                      }

                      final balance = totalIncome - totalExpense;

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _header(context),
                            const SizedBox(height: 22),
                            _card(name),
                            const SizedBox(height: 26),
                            Text('Card controls',
                                style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 14),
                            _controlsCard(),
                            const SizedBox(height: 20),
                            _balanceCard(balance,
                                loading: isLoadingTx, error: hasError),
                            const SizedBox(height: 14),
                            _accountCard(accountNumber, name, school),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Text(
                                'Note: This is a demo fintech card. It cannot receive real bank transfers or make real payments yet.',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
      bottomNavigationBar: user == null ? null : _detailsBar(),
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
        Text('My card',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
      ],
    );
  }

  // ---- Card preview ----
  Widget _card(String name) {
    final hide = hideCardDetails || isFrozen;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          height: 205,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadow.soft,
          ),
          child: Stack(
            children: [
              // Soft lime glow in the top-right corner.
              Positioned(
                right: -10,
                top: -10,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.10),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('STASH',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                      // Card chip.
                      Container(
                        width: 42,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    hide ? _cardMasked : _cardNumber,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _cardInfo('CARD HOLDER', name.toUpperCase()),
                      const SizedBox(width: 22),
                      _cardInfo('EXPIRES', hide ? '**/**' : _cardExp),
                      if (!hide) ...[
                        const SizedBox(width: 22),
                        _cardInfo('CVV', _cardCvv),
                      ],
                      const Spacer(),
                      _paymentLogo(),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isFrozen)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                    color: Colors.white.withOpacity(0.5), width: 1.2),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.ac_unit_rounded, color: Colors.white, size: 30),
                  SizedBox(height: 6),
                  Text('FROZEN',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _paymentLogo() {
    return SizedBox(
      width: 46,
      height: 28,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.danger.withOpacity(0.9),
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(
          value.length > 14 ? '${value.substring(0, 14)}...' : value,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  // ---- Controls ----
  Widget _controlsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: [
          _toggleRow('Freeze card', 'Temporarily block all transactions',
              isFrozen, _toggleFreeze),
          _divider(),
          _toggleRow('Online payments', 'Allow web & app purchases',
              onlinePayments, (v) => setState(() => onlinePayments = v)),
          _divider(),
          _toggleRow('ATM withdrawals', 'Allow cash withdrawals',
              atmWithdrawals, (v) => setState(() => atmWithdrawals = v)),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
      height: 1, thickness: 1, color: AppColors.border, indent: 18, endIndent: 18);

  Widget _toggleRow(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.onAccent,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.border,
          ),
        ],
      ),
    );
  }

  // ---- Balance ----
  Widget _balanceCard(double balance,
      {required bool loading, required bool error}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.soft,
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Card balance',
                    style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
                const SizedBox(height: 5),
                if (loading)
                  const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppColors.primary),
                  )
                else
                  Text(error ? '₦ —' : Money.naira(balance),
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Account ----
  Widget _accountCard(String accountNumber, String name, String school) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STASH Microfinance',
              style: TextStyle(
                  color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(accountNumber,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                        letterSpacing: 1.5)),
              ),
              IconButton(
                onPressed: () => _copyAccountNumber(accountNumber),
                icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(name,
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(school, style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }

  // ---- View card details button ----
  Widget _detailsBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.card,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(color: AppColors.border)),
          ),
          onPressed: _toggleDetails,
          child: Text(
              hideCardDetails ? 'View card details' : 'Hide card details',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}
