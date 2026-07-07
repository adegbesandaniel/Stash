import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/budget_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/liquid_nav_bar.dart';
import 'dashboard_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'add_money_screen.dart';

/// STASH — Smart Budget (black liquid UI).
///
/// Shows the live monthly budget overview (spent vs budget), an AI spending
/// suggestion derived from the user's real transactions, and a per-category
/// breakdown. The budget itself is set/edited via the "Edit" sheet, which keeps
/// the original balance + days calculator and BudgetService().saveBudget logic.
class BudgetSetupScreen extends StatefulWidget {
  const BudgetSetupScreen({super.key});

  @override
  State<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends State<BudgetSetupScreen> {
  final balanceController = TextEditingController();
  final daysController = TextEditingController();

  bool isLoading = false;

  static const int _maxDays = 365;

  // Spending categories that are really transfers into savings/locked vaults,
  // not actual spending — excluded from the budget "spent" figure.
  static const Set<String> _savingsCategories = {'Locked Money', 'Savings Goal'};

  static const List<Color> _dotColors = [
    AppColors.success,
    AppColors.primary,
    AppColors.danger,
    Color(0xFF8C8F84),
  ];

  @override
  void dispose() {
    balanceController.dispose();
    daysController.dispose();
    super.dispose();
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
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

  IconData _categoryIcon(String category) {
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('meal') || c.contains('groc')) {
      return Icons.restaurant_rounded;
    }
    if (c.contains('transport') || c.contains('trip') || c.contains('fuel')) {
      return Icons.directions_bus_rounded;
    }
    if (c.contains('subscription') || c.contains('netflix')) {
      return Icons.subscriptions_rounded;
    }
    if (c.contains('airtime') || c.contains('call')) {
      return Icons.phone_android_rounded;
    }
    if (c.contains('data') || c.contains('wifi') || c.contains('internet')) {
      return Icons.wifi_rounded;
    }
    if (c.contains('shop') || c.contains('cloth')) {
      return Icons.shopping_bag_rounded;
    }
    if (c.contains('bill') || c.contains('electric') || c.contains('rent')) {
      return Icons.receipt_long_rounded;
    }
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<DocumentSnapshot>(
          stream: BudgetService().getBudget(),
          builder: (context, budgetSnap) {
            final budgetData =
                budgetSnap.data?.data() as Map<String, dynamic>?;
            final dailyBudget = _toDouble(budgetData?['dailyBudget']);
            final now = DateTime.now();
            final daysInMonth =
                DateUtils.getDaysInMonth(now.year, now.month);
            final monthlyBudget = dailyBudget * daysInMonth;

            return StreamBuilder<QuerySnapshot>(
              stream: FirestoreService().getTransactions(),
              builder: (context, txnSnap) {
                double spent = 0;
                final Map<String, double> categoryTotals = {};

                if (txnSnap.hasData) {
                  for (final doc in txnSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data == null) continue;
                    if (data['type'] != 'expense') continue;
                    final category = (data['category'] ?? 'Other').toString();
                    if (_savingsCategories.contains(category)) continue;
                    final date =
                        DateTime.tryParse((data['date'] ?? '').toString());
                    if (date == null) continue;
                    if (date.year != now.year || date.month != now.month) {
                      continue;
                    }
                    final amount = _toDouble(data['amount']);
                    spent += amount;
                    categoryTotals[category] =
                        (categoryTotals[category] ?? 0) + amount;
                  }
                }

                final sorted = categoryTotals.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final perCatLimit = sorted.isEmpty
                    ? 0.0
                    : monthlyBudget / sorted.length;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(context),
                      const SizedBox(height: 20),
                      if (monthlyBudget <= 0)
                        _setupCard()
                      else ...[
                        _budgetCard(spent, monthlyBudget),
                        const SizedBox(height: 24),
                        Text('AI suggestion',
                            style: TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        _aiCard(_suggestion(
                            spent, monthlyBudget, sorted)),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Category breakdown',
                                style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900)),
                            GestureDetector(
                              onTap: _openEditSheet,
                              behavior: HitTestBehavior.opaque,
                              child: const Text('Edit',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (sorted.isEmpty)
                          _emptyCategories()
                        else
                          ...List.generate(sorted.length, (i) {
                            return _categoryRow(
                              i,
                              sorted[i].key,
                              sorted[i].value,
                              perCatLimit,
                            );
                          }),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: _bottomNav(context),
    );
  }

  // ---- Header ----
  Widget _header(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen()));
            }
          },
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
        Text('Smart budget',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
      ],
    );
  }

  // ---- Monthly budget overview card ----
  Widget _budgetCard(double spent, double monthlyBudget) {
    final usedPct =
        monthlyBudget <= 0 ? 0.0 : (spent / monthlyBudget).clamp(0.0, 1.0);
    final left = (monthlyBudget - spent);
    final pctLabel = (monthlyBudget <= 0 ? 0 : spent / monthlyBudget * 100)
        .clamp(0, 999)
        .toStringAsFixed(0);
    final over = left < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly budget',
              style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(Money.naira(spent),
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
              const SizedBox(width: 6),
              Text('/ ${Money.naira(monthlyBudget)}',
                  style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Stack(
              children: [
                Container(
                    height: 10, color: Colors.white.withOpacity(0.08)),
                FractionallySizedBox(
                  widthFactor: usedPct,
                  child: Container(
                    height: 10,
                    color: over ? AppColors.danger : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$pctLabel% used',
                  style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(
                  over
                      ? '${Money.naira(left.abs())} over'
                      : '${Money.naira(left)} left',
                  style: TextStyle(
                      color: over ? AppColors.danger : AppColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  // ---- AI suggestion callout ----
  Widget _aiCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withOpacity(0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: AppColors.text, height: 1.45, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  String _suggestion(
      double spent, double monthlyBudget, List<MapEntry<String, double>> sorted) {
    if (spent <= 0) {
      return "You haven't spent anything this month yet. Great start — keep it steady to stay within your budget.";
    }
    if (spent > monthlyBudget) {
      final over = spent - monthlyBudget;
      return "You've gone ${Money.naira(over)} over your monthly budget. Try pausing non-essential spending for the rest of the month.";
    }
    if (sorted.isNotEmpty) {
      final top = sorted.first;
      final share = (top.value / spent * 100).toStringAsFixed(0);
      return "$share% of your spending this month went to ${top.key}. Setting a daily cap here is the fastest way to stay on track.";
    }
    final left = monthlyBudget - spent;
    return 'You have ${Money.naira(left)} left this month. Spread it evenly to avoid running out early.';
  }

  // ---- Category row ----
  Widget _categoryRow(int index, String name, double spent, double limit) {
    final ratio = limit <= 0 ? 0.0 : spent / limit;
    final pct = (ratio * 100).clamp(0, 999).toStringAsFixed(0);

    String label;
    Color color;
    if (ratio >= 0.85) {
      label = 'High';
      color = AppColors.danger;
    } else if (ratio >= 0.70) {
      label = 'On track';
      color = AppColors.success;
    } else {
      label = 'On track';
      color = const Color(0xFF4D8DFF);
    }

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
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _dotColors[index % _dotColors.length].withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_categoryIcon(name),
                color: _dotColors[index % _dotColors.length], size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                    limit <= 0
                        ? Money.naira(spent)
                        : '${Money.naira(spent)} of ${Money.naira(limit)}',
                    style: TextStyle(
                        color: AppColors.muted, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('$pct%',
              style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _emptyCategories() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.soft,
      ),
      child: Text('No spending recorded this month yet.',
          style: TextStyle(color: AppColors.muted)),
    );
  }

  // ---- Setup prompt (no budget yet) ----
  Widget _setupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.heroGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.calculate_rounded,
              color: AppColors.primary, size: 38),
          const SizedBox(height: 16),
          Text('Set up your budget',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(
              'Tell STASH how much you have and how long it should last. We\'ll work out a daily and monthly budget for you.',
              style: TextStyle(color: AppColors.muted, height: 1.5)),
          const SizedBox(height: 20),
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
              onPressed: _openEditSheet,
              child: const Text('Create budget',
                  style: TextStyle(
                      color: Color(0xFF0A0A0C),
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Edit / create budget sheet (keeps original calculator) ----
  Future<void> _saveBudget(BuildContext sheetCtx) async {
    FocusScope.of(context).unfocus();

    final balance = double.tryParse(balanceController.text.trim());
    final days = int.tryParse(daysController.text.trim());

    if (balance == null || balance <= 0) {
      _showError('Enter a valid balance greater than zero.');
      return;
    }
    if (days == null || days <= 0) {
      _showError('Enter how many days it should last.');
      return;
    }
    if (days > _maxDays) {
      _showError('Days must be $_maxDays or fewer.');
      return;
    }

    final calculatedBudget = balance / days;
    setState(() => isLoading = true);

    final error = await BudgetService().saveBudget(
      balance: balance,
      days: days,
      dailyBudget: calculatedBudget,
    );
    if (!mounted) return;
    setState(() => isLoading = false);

    if (error != null) {
      _showError(error);
      return;
    }
    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
    _showSuccess('Budget saved successfully');
  }

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  Text('Set your budget',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text)),
                  const SizedBox(height: 16),
                  _BalanceSuggestion(
                    onUse: (v) {
                      balanceController.text = v.toStringAsFixed(0);
                      setSheet(() {});
                    },
                  ),
                  _PremiumField(
                    controller: balanceController,
                    label: 'Current balance',
                    icon: Icons.account_balance_wallet_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                  ),
                  _PremiumField(
                    controller: daysController,
                    label: 'Number of days',
                    icon: Icons.calendar_today_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor:
                            AppColors.primary.withOpacity(0.7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md)),
                      ),
                      onPressed:
                          isLoading ? null : () => _saveBudget(ctx),
                      child: isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Color(0xFF0A0A0C)))
                          : const Text('Save budget',
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
        });
      },
    );
  }

  // ---- Bottom navigation (Budget = index 2) ----
  void _replace(Widget page) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _bottomNav(BuildContext context) => LiquidNavBar(
        currentIndex: 2,
        onCenterTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddMoneyScreen())),
        onTap: (i) {
          switch (i) {
            case 0:
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                _replace(const DashboardScreen());
              }
              break;
            case 1:
              _replace(const AnalyticsScreen());
              break;
            case 3:
              _replace(const ProfileScreen());
              break;
            default:
              break;
          }
        },
        items: const [
          LiquidNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home'),
          LiquidNavItem(icon: Icons.bar_chart_rounded, label: 'Analytics'),
          LiquidNavItem(
              icon: Icons.calculate_outlined,
              activeIcon: Icons.calculate_rounded,
              label: 'Budget'),
          LiquidNavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile'),
        ],
      );
}

/// Live wallet balance (income - expense) pulled from the user's transactions,
/// so Smart Budget can pre-fill the amount the student actually has.
class _BalanceSuggestion extends StatelessWidget {
  final ValueChanged<double> onUse;
  const _BalanceSuggestion({required this.onUse});

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService().getTransactions(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        double income = 0;
        double expense = 0;
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          final value = _toDouble(data['amount']);
          if (data['type'] == 'income') {
            income += value;
          } else if (data['type'] == 'expense') {
            expense += value;
          }
        }
        final balance = income - expense;
        if (balance <= 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => onUse(balance),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your current balance',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(Money.naira(balance),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text('Use',
                      style: TextStyle(
                          color: Color(0xFF0A0A0C),
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType ?? TextInputType.number,
        inputFormatters: inputFormatters,
        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.muted),
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}
