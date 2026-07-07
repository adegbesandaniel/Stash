import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/transaction_model.dart';
import '../services/balance_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import 'widgets/success_dialog.dart';

/// STASH — Buy Airtime (black liquid UI).
///
/// Network picker + phone + amount (with quick presets), then a single
/// Continue action. All spend logic is preserved: validation,
/// BalanceService().guardSpend, the recorded 'Airtime' expense, and the
/// success dialog.
class AirtimeScreen extends StatefulWidget {
  const AirtimeScreen({super.key});

  @override
  State<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends State<AirtimeScreen> {
  final phoneController = TextEditingController();
  final amountController = TextEditingController();

  String selectedNetwork = 'MTN';
  bool isLoading = false;

  final networks = const ['MTN', 'Airtel', 'Glo', '9mobile'];
  static const List<double> _presets = [100, 200, 500, 1000];
  static const double _minAmount = 50;
  static const double _maxAmount = 50000;

  @override
  void dispose() {
    phoneController.dispose();
    amountController.dispose();
    super.dispose();
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

  Future<void> _buyAirtime() async {
    FocusScope.of(context).unfocus();

    final phone = phoneController.text.trim();
    final rawAmount = amountController.text.trim();
    final amount = double.tryParse(rawAmount);

    if (phone.isEmpty || rawAmount.isEmpty) {
      _showError('Please enter phone number and amount.');
      return;
    }
    if (!RegExp(r'^0\d{10}$').hasMatch(phone)) {
      _showError('Enter a valid 11-digit phone number (e.g. 08012345678).');
      return;
    }
    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount greater than zero.');
      return;
    }
    if (amount < _minAmount) {
      _showError('Minimum airtime amount is ${Money.naira(_minAmount)}.');
      return;
    }
    if (amount > _maxAmount) {
      _showError('Maximum airtime amount is ${Money.naira(_maxAmount)}.');
      return;
    }

    setState(() => isLoading = true);

    final guard = await BalanceService().guardSpend(amount);
    if (!mounted) return;
    if (guard != null) {
      setState(() => isLoading = false);
      _showError(guard);
      return;
    }

    // Simulated network call (demo mode).
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final transaction = TransactionModel(
      type: 'expense',
      category: 'Airtime',
      amount: amount,
      note: '$selectedNetwork airtime for $phone',
      date: DateTime.now(),
    );

    final error = await FirestoreService().addTransaction(transaction);
    if (!mounted) return;
    setState(() => isLoading = false);

    if (error != null) {
      _showError(error);
      return;
    }

    phoneController.clear();
    amountController.clear();
    setState(() {});

    await completeTransaction(
      context,
      title: 'Airtime Successful',
      message:
          'You bought ${Money.naira(amount)} $selectedNetwork airtime for $phone.',
      amount: amount,
      type: 'expense',
      category: 'Airtime',
      note: '$selectedNetwork airtime for $phone',
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
              const SizedBox(height: 22),
              _phoneField(),
              const SizedBox(height: 24),
              Text('Network',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (int i = 0; i < networks.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: i == networks.length - 1 ? 0 : 10),
                        child: _networkTile(networks[i]),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Amount',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _amountField(),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (int i = 0; i < _presets.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: i == _presets.length - 1 ? 0 : 10),
                        child: _presetTile(_presets[i]),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _continueBar(),
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
        Text('Buy airtime',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
      ],
    );
  }

  // ---- Phone field ----
  Widget _phoneField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11),
        ],
        style: TextStyle(
            fontWeight: FontWeight.w700, color: AppColors.text, fontSize: 16),
        decoration: InputDecoration(
          labelText: 'Phone number',
          labelStyle: TextStyle(color: AppColors.muted),
          hintText: '080 1234 5678',
          hintStyle: TextStyle(color: AppColors.muted.withOpacity(0.6)),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
    );
  }

  // ---- Amount field ----
  Widget _amountField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: amountController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        onChanged: (_) => setState(() {}),
        style: TextStyle(
            fontWeight: FontWeight.w800, color: AppColors.text, fontSize: 18),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primary),
          hintText: 'Enter amount',
          hintStyle: TextStyle(color: AppColors.muted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  // ---- Preset tile ----
  Widget _presetTile(double value) {
    final current = double.tryParse(amountController.text.trim());
    final selected = current == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        amountController.text = value.toStringAsFixed(0);
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1),
        ),
        child: Text(Money.compact(value),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.primary : AppColors.text)),
      ),
    );
  }

  // ---- Network tile ----
  Widget _networkTile(String n) {
    final selected = selectedNetwork == n;
    return GestureDetector(
      onTap: () => setState(() => selectedNetwork = n),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1),
        ),
        child: Text(n,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.primary : AppColors.text)),
      ),
    );
  }

  // ---- Continue button ----
  Widget _continueBar() {
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
          onPressed: isLoading ? null : _buyAirtime,
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Color(0xFF0A0A0C)))
              : const Text('Continue',
                  style: TextStyle(
                      color: Color(0xFF0A0A0C),
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}
