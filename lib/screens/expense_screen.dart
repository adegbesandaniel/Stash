import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../services/balance_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import 'widgets/money_form.dart';
import 'widgets/success_dialog.dart';
import 'transfer_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  String selectedCategory = 'Food';
  bool isLoading = false;

  static const double _maxAmount = 10000000;

  final categories = [
    'Food',
    'Transport',
    'Data',
    'School',
    'Shopping',
    'Bills',
    'Emergency',
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

  Future<void> saveExpense() async {
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

    final guard = await BalanceService().guardSpend(amount);
    if (!mounted) return;
    if (guard != null) {
      setState(() => isLoading = false);
      _showError(guard);
      return;
    }

    final transaction = TransactionModel(
      type: 'expense',
      category: selectedCategory,
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
      title: 'Expense Recorded',
      message: 'You spent ${Money.naira(amount)} on $selectedCategory.',
      amount: amount,
      type: 'expense',
      category: selectedCategory,
      note: noteController.text.trim(),
    );
    if (!mounted) return;
    // After saving an expense, take the user to the Transfer screen so they
    // can immediately send the money if the expense was a payment/transfer.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TransferScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumMoneyForm(
      title: 'Add Expense',
      subtitle: 'Track what you spent so STASH can protect your budget.',
      icon: Icons.arrow_upward_rounded,
      accent: AppColors.danger,
      amountController: amountController,
      noteController: noteController,
      selectedValue: selectedCategory,
      values: categories,
      sectionLabel: 'Expense Category',
      buttonText: 'Save Expense',
      isLoading: isLoading,
      onChanged: (value) => setState(() => selectedCategory = value),
      onSave: isLoading ? null : saveExpense,
    );
  }
}
