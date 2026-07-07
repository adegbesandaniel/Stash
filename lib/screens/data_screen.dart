import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/transaction_model.dart';
import '../services/balance_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import 'widgets/success_dialog.dart';

class _DataPlan {
  final String data;
  final String duration;
  final String label;
  final double amount;
  const _DataPlan(this.data, this.duration, this.label, this.amount);
}

/// STASH — Buy Data (black liquid UI).
///
/// Network picker + popular plans, then a single Continue action. All spend
/// logic is preserved: phone validation, BalanceService().guardSpend, the
/// recorded 'Data' expense, and the success dialog.
class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final phoneController = TextEditingController();

  String selectedNetwork = 'MTN';
  int selectedPlanIndex = 0;
  bool isLoading = false;

  final networks = const ['MTN', 'Airtel', 'Glo', '9mobile'];

  final plans = const [
    _DataPlan('1GB', '1 day', 'Daily plan', 350),
    _DataPlan('3.5GB', '7 days', 'Weekly plan', 1200),
    _DataPlan('15GB', '30 days', 'Monthly plan', 4500),
    _DataPlan('40GB', '30 days', 'Monthly plan', 10000),
  ];

  @override
  void dispose() {
    phoneController.dispose();
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

  Future<void> _buyData() async {
    FocusScope.of(context).unfocus();

    final phone = phoneController.text.trim();
    final plan = plans[selectedPlanIndex];
    final amount = plan.amount;
    final planLabel = '${plan.data} ${plan.duration}';

    if (phone.isEmpty) {
      _showError('Please enter phone number.');
      return;
    }
    if (!RegExp(r'^0\d{10}$').hasMatch(phone)) {
      _showError('Enter a valid 11-digit phone number (e.g. 08012345678).');
      return;
    }
    if (amount <= 0) {
      _showError('Please choose a valid data bundle.');
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
      category: 'Data',
      amount: amount,
      note: '$selectedNetwork $planLabel for $phone',
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
    setState(() {});

    await completeTransaction(
      context,
      title: 'Data Successful',
      message: 'You bought $planLabel ($selectedNetwork) for $phone.',
      amount: amount,
      type: 'expense',
      category: 'Data',
      note: '$selectedNetwork $planLabel for $phone',
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
              Text('Popular plans',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              ...List.generate(
                  plans.length, (i) => _planCard(i, plans[i])),
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
        Text('Buy data',
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

  // ---- Plan card ----
  Widget _planCard(int index, _DataPlan plan) {
    final selected = selectedPlanIndex == index;
    return GestureDetector(
      onTap: () => setState(() => selectedPlanIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1),
          boxShadow: AppShadow.soft,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${plan.data} · ${plan.duration}',
                      style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(plan.label,
                      style: TextStyle(
                          color: AppColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
            Text(Money.naira(plan.amount),
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          ],
        ),
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
          onPressed: isLoading ? null : _buyData,
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
