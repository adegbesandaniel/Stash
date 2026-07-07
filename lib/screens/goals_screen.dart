import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/goal_model.dart';
import '../models/transaction_model.dart';
import '../services/balance_service.dart';
import '../services/firestore_service.dart';
import '../services/goal_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  static const List<String> _emojis = [
    '🎯', '💻', '📱', '🎓', '🚗', '🏠', '✈️', '🎁', '💰', '👟'
  ];

  static const double _maxAmount = 10000000;

  static List<TextInputFormatter> get _moneyFormatters => [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ];

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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
            onPressed: _openCreateSheet,
            child: const Text('Create new goal',
                style: TextStyle(
                    color: Color(0xFF0A0A0C),
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: GoalService().getGoals(),
          builder: (context, snapshot) {
            final hasError = snapshot.hasError;
            final docs = snapshot.data?.docs ?? [];

            double totalSaved = 0;
            double totalTarget = 0;
            final goals = <GoalModel>[];
            for (final d in docs) {
              final map = d.data() as Map<String, dynamic>?;
              if (map == null) continue;
              final g = GoalModel.fromDoc(d.id, map);
              goals.add(g);
              totalSaved += g.saved;
              totalTarget += g.target;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
              children: [
                _header(),
                const SizedBox(height: 18),
                _summaryCard(totalSaved, totalTarget, goals.length),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Active goals',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text)),
                    GestureDetector(
                      onTap: _openCreateSheet,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.add_rounded,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('New goal',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (hasError)
                  _errorState()
                else if (goals.isEmpty)
                  _emptyState()
                else
                  ...goals.asMap().entries.map((e) => _goalCard(e.value, e.key)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppColors.text),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Savings Goals',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text)),
            Text('Save towards what matters',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(double saved, double target, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: [
          Text('Total saved across goals',
              style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
          const SizedBox(height: 8),
          Text(Money.naira(saved),
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1)),
        ],
      ),
    );
  }

  static const List<Color> _accentColors = [
    AppColors.primary,
    Color(0xFF4D8DFF),
    AppColors.success,
  ];

  Widget _goalCard(GoalModel g, int index) {
    final accent = _accentColors[index % _accentColors.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(g.icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.title.isEmpty ? 'Goal' : g.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text(
                      g.isComplete
                          ? 'Goal reached 🎉'
                          : '${Money.naira(g.remaining)} to go',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color:
                              g.isComplete ? AppColors.success : AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _confirmDelete(g),
                icon: Icon(Icons.delete_outline_rounded,
                    color: AppColors.muted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Stack(
              children: [
                Container(height: 10, color: AppColors.primarySoft),
                FractionallySizedBox(
                  widthFactor: g.progress,
                  child: Container(height: 10, color: accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${Money.naira(g.saved)} / ${Money.naira(g.target)}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              Text('${(g.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: accent)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: g.isComplete ? null : () => _openAddFundsSheet(g),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(g.isComplete ? 'Completed' : 'Add money',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 14),
          Text('No goals yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          Text('Create your first savings goal and start stashing.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.muted),
          const SizedBox(height: 14),
          Text('Could not load your goals',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          Text('Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ),
    );
  }

  // ---------------- Sheets ----------------

  void _openCreateSheet() {
    final titleC = TextEditingController();
    final targetC = TextEditingController();
    String selectedIcon = _emojis.first;
    DateTime? targetDate;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
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
                  Text('New Savings Goal',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _emojis.map((e) {
                      final sel = e == selectedIcon;
                      return GestureDetector(
                        onTap: () => setSheet(() => selectedIcon = e),
                        child: Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel ? AppColors.primary : AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  _PremiumField(
                      controller: titleC,
                      label: 'Goal name',
                      icon: Icons.flag_outlined,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 40),
                  const SizedBox(height: 12),
                  _PremiumField(
                      controller: targetC,
                      label: 'Target amount (₦)',
                      icon: Icons.savings_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: _moneyFormatters),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setSheet(() => targetDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_outlined,
                              size: 20, color: AppColors.muted),
                          const SizedBox(width: 12),
                          Text(
                            targetDate == null
                                ? 'Target date (optional)'
                                : _formatDate(targetDate!),
                            style: TextStyle(
                                color: targetDate == null
                                    ? AppColors.muted
                                    : AppColors.text,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.hero,
                        foregroundColor: Color(0xFF0A0A0C),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final title = titleC.text.trim();
                              final target =
                                  double.tryParse(targetC.text.trim()) ?? 0;
                              if (title.isEmpty) {
                                _sheetError(ctx, 'Enter a goal name.');
                                return;
                              }
                              if (target <= 0) {
                                _sheetError(
                                    ctx, 'Enter a valid target amount.');
                                return;
                              }
                              if (target > _maxAmount) {
                                _sheetError(ctx,
                                    'Target is too large. Maximum is ${Money.naira(_maxAmount)}.');
                                return;
                              }
                              setSheet(() => saving = true);
                              final err = await GoalService().createGoal(
                                title: title,
                                target: target,
                                icon: selectedIcon,
                                targetDate: targetDate?.toIso8601String(),
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (err != null) {
                                _showError(err);
                              } else {
                                _showSuccess('Goal created');
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF0A0A0C)))
                          : const Text('Create Goal',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        });
      },
    ).whenComplete(() {
      titleC.dispose();
      targetC.dispose();
    });
  }

  void _openAddFundsSheet(GoalModel g) {
    final amountC = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
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
                  Text('Add to ${g.icon} ${g.title}',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text)),
                  const SizedBox(height: 16),
                  _PremiumField(
                      controller: amountC,
                      label: 'Amount (₦)',
                      icon: Icons.payments_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: _moneyFormatters),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.hero,
                        foregroundColor: Color(0xFF0A0A0C),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final amount =
                                  double.tryParse(amountC.text.trim()) ?? 0;
                              if (amount <= 0) {
                                _sheetError(
                                    ctx, 'Enter a valid amount.');
                                return;
                              }
                              if (amount > _maxAmount) {
                                _sheetError(ctx,
                                    'Amount is too large. Maximum is ${Money.naira(_maxAmount)}.');
                                return;
                              }
                              setSheet(() => saving = true);
                              final guard =
                                  await BalanceService().guardSave(amount);
                              if (!ctx.mounted) return;
                              if (guard != null) {
                                setSheet(() => saving = false);
                                _sheetError(ctx, guard);
                                return;
                              }
                              final err =
                                  await GoalService().addFunds(g.id, amount);
                              if (!ctx.mounted) return;
                              if (err != null) {
                                setSheet(() => saving = false);
                                Navigator.pop(ctx);
                                _showError(err);
                                return;
                              }
                              // Deduct the saved amount from the available
                              // balance by recording it as an expense.
                              await FirestoreService().addTransaction(
                                TransactionModel(
                                  type: 'expense',
                                  category: 'Savings Goal',
                                  amount: amount,
                                  note: 'Saved to ${g.title}',
                                  date: DateTime.now(),
                                ),
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _showSuccess(
                                  '${Money.naira(amount)} added to ${g.title}');
                            },
                      child: saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF0A0A0C)))
                          : const Text('Add money',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        });
      },
    ).whenComplete(() {
      amountC.dispose();
    });
  }

  void _sheetError(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _confirmDelete(GoalModel g) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Delete goal?',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
        content: Text('“${g.title}” will be removed permanently.',
            style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await GoalService().deleteGoal(g.id);
              if (err != null) {
                _showError(err);
              } else {
                _showSuccess('Goal deleted');
              }
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Reusable premium input field (same style used across STASH).
class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int? maxLength;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.muted),
        prefixIcon: Icon(icon, color: AppColors.muted),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
