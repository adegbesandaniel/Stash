import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/transaction_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import 'paystack_checkout_screen.dart';
import 'widgets/success_dialog.dart';

/// An income source the user can fund via Paystack.
class _IncomeType {
  final String label;
  final IconData icon;
  const _IncomeType(this.label, this.icon);
}

/// Lets the user add real money to their STASH wallet via Paystack, tagged with
/// the income source (Funding, Allowance, Scholarship, Side Hustle, Gift).
/// CLIENT-SIDE mode: checkout runs in-app with the public key, then the
/// payment is recorded as an income transaction so the balance updates.
class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final TextEditingController _amountController = TextEditingController();
  final PaymentService _paymentService = PaymentService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  final List<int> _presets = [1000, 2000, 5000, 10000];
  static const double _minAmount = 100;
  static const double _maxAmount = 1000000;

  static const List<_IncomeType> _incomeTypes = [
    _IncomeType('Funding', Icons.account_balance_wallet_rounded),
    _IncomeType('Allowance', Icons.volunteer_activism_rounded),
    _IncomeType('Scholarship', Icons.school_rounded),
    _IncomeType('Side Hustle', Icons.work_rounded),
    _IncomeType('Gift', Icons.card_giftcard_rounded),
  ];

  String _selectedType = 'Funding';
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _applyPreset(int amount) {
    _amountController.text = amount.toString();
    setState(() {});
  }

  String get _noteForType {
    if (_selectedType == 'Funding') return 'Wallet funding via Paystack';
    return '$_selectedType received via Paystack';
  }

  Future<void> _fund() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < _minAmount) {
      _showError('Enter at least ${Money.naira(_minAmount)}.');
      return;
    }
    if (amount > _maxAmount) {
      _showError('Maximum top-up is ${Money.naira(_maxAmount)}.');
      return;
    }

    final email = _authService.currentUser?.email;
    if (email == null || email.isEmpty) {
      _showError('You must be signed in to add money.');
      return;
    }

    if (PaymentService.publicKey.contains('REPLACE_WITH_YOUR')) {
      _showError(
          'Paystack public key not set yet. Add it in payment_service.dart.');
      return;
    }

    setState(() => _loading = true);
    try {
      final reference = _paymentService.generateReference();

      final ref = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => PaystackCheckoutScreen(
            publicKey: PaymentService.publicKey,
            email: email,
            amountNaira: amount,
            reference: reference,
          ),
        ),
      );

      if (ref == null) {
        _showError('Payment cancelled.');
        return;
      }

      // Record the payment as income so the wallet balance updates.
      final err = await _firestoreService.addTransaction(
        TransactionModel(
          type: 'income',
          category: _selectedType,
          amount: amount,
          note: _noteForType,
          date: DateTime.now(),
        ),
      );
      if (!mounted) return;
      if (err != null) {
        _showError(err);
        return;
      }

      await completeTransaction(
        context,
        title:
            _selectedType == 'Funding' ? 'Wallet Funded' : '$_selectedType Added',
        message: 'Your wallet has been credited with ${Money.naira(amount)}.',
        amount: amount,
        type: 'income',
        category: _selectedType,
        note: _noteForType,
        reference: reference,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showError('Could not complete payment. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Add Money',
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadow.heroGlow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('How much would you like to add?',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('₦',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            onChanged: (_) => setState(() {}),
                            cursorColor: Colors.white,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900),
                            decoration: const InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presets.map((p) {
                  return GestureDetector(
                    onTap: () => _applyPreset(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: AppShadow.soft,
                      ),
                      child: Text(Money.naira(p),
                          style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w800)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text('Income source',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: AppColors.text)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _incomeTypes.map((t) {
                  final selected = t.label == _selectedType;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = t.label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: AppShadow.soft,
                        border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.icon,
                              size: 18,
                              color: selected
                                  ? Colors.white
                                  : AppColors.primary),
                          const SizedBox(width: 8),
                          Text(t.label,
                              style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.text,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payments are secured by Paystack. Cards, bank transfer and USSD are supported.',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 12,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  onPressed: _loading ? null : _fund,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Color(0xFF0A0A0C), strokeWidth: 2.4))
                      : const Text('Continue to Payment',
                          style: TextStyle(
                              color: Color(0xFF0A0A0C),
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
