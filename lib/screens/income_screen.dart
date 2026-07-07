import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import 'widgets/money_form.dart';
import 'widgets/success_dialog.dart';

class AddIncomeScreen extends StatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  String selectedSource = 'Allowance';
  bool isLoading = false;

  static const double _maxAmount = 10000000;

  final sources = [
    'Allowance',
    'Gift',
    'Side Hustle',
    'Freelance',
    'Scholarship',
    'Other',
  ];

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  void _showError(String message) {
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

  Future<void> saveIncome() async {
    FocusScope.of(context).unfocus();

    final amount = double.tryParse(amountController.text.trim());

    // --- Up-front validation ---
    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount greater than zero.');
      return;
    }
    if (amount > _maxAmount) {
      _showError('Amount is too large. Maximum is ${Money.naira(_maxAmount)}.');
      return;
    }

    setState(() => isLoading = true);

    final transaction = TransactionModel(
      type: 'income',
      category: selectedSource,
      amount: amount,
      note: noteController.text.trim(),
      date: DateTime.now(),
    );

    final error = await FirestoreService().addTransaction(transaction);
    if (!mounted) return;
    setState(() => isLoading = false);

    if (error != null) {
      _showError(error);
      return;
    }

    await completeTransaction(
      context,
      title: 'Income Added',
      message: 'You added ${Money.naira(amount)} from $selectedSource.',
      amount: amount,
      type: 'income',
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumMoneyForm(
      title: 'Add Income',
      subtitle:
          'Record money you received and keep your STASH balance updated.',
      icon: Icons.arrow_downward_rounded,
      accent: AppColors.success,
      amountController: amountController,
      noteController: noteController,
      selectedValue: selectedSource,
      values: sources,
      sectionLabel: 'Income Source',
      buttonText: 'Save Income',
      isLoading: isLoading,
      onChanged: (value) => setState(() => selectedSource = value),
      onSave: isLoading ? null : saveIncome,
    );
  }
}
