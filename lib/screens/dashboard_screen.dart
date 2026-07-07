import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_service.dart';
import '../services/budget_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

import 'transaction_history_screen.dart';
import 'budget_setup_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'transfer_screen.dart';
import 'airtime_screen.dart';
import 'data_screen.dart';
import 'lock_money_screen.dart';
import 'virtual_card_screen.dart';
import 'add_money_screen.dart';

import '../widgets/liquid_nav_bar.dart';

/// STASH — Home Dashboard (black liquid UI).
///
/// All Firebase logic is preserved exactly:
///  • Transactions stream → income / expense / spent-today / balance
///  • Budget stream → saved daily budget
///  • User doc stream → display name
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool hideBalance = false;

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirestoreService().getTransactions(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _errorState();
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }

            double totalIncome = 0, totalExpense = 0, spentToday = 0;
            final now = DateTime.now();

            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) continue;
                final type = data['type'];
                final amount = _toDouble(data['amount']);
                final date =
                    DateTime.tryParse((data['date'] ?? '').toString());
                if (type == 'income') {
                  totalIncome += amount;
                } else if (type == 'expense') {
                  totalExpense += amount;
                  final category = (data['category'] ?? '').toString();
                  final isSaving = category == 'Locked Money' ||
                      category == 'Savings Goal';
                  if (!isSaving &&
                      date != null &&
                      date.year == now.year &&
                      date.month == now.month &&
                      date.day == now.day) {
                    spentToday += amount;
                  }
                }
              }
            }

            final balance = totalIncome - totalExpense;
            final double recommendedBudget = balance > 0 ? balance / 7 : 0.0;

            return StreamBuilder<DocumentSnapshot>(
              stream: BudgetService().getBudget(),
              builder: (context, budgetSnapshot) {
                double savedBudget = recommendedBudget;
                if (budgetSnapshot.hasData &&
                    budgetSnapshot.data!.data() != null) {
                  final budgetData =
                      budgetSnapshot.data!.data() as Map<String, dynamic>;
                  savedBudget = (budgetData['dailyBudget'] ?? recommendedBudget)
                      .toDouble();
                }

                final overSpending =
                    savedBudget > 0 && spentToday > savedBudget;
                final spentProgress = savedBudget > 0
                    ? (spentToday / savedBudget).clamp(0.0, 1.0)
                    : 0.0;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(currentUser),
                      const SizedBox(height: 22),
                      _balanceCard(balance),
                      const SizedBox(height: 26),
                      _sectionTitle('Quick actions'),
                      const SizedBox(height: 14),
                      _quickActionsRow(context),
                      const SizedBox(height: 24),
                      _budgetCard(
                        savedBudget: savedBudget,
                        spentToday: spentToday,
                        progress: spentProgress.toDouble(),
                        overSpending: overSpending,
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                              child: _sectionTitle('Recent transactions')),
                          GestureDetector(
                            onTap: () => _push(
                                context, const TransactionHistoryScreen()),
                            child: const Text('See all',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                        _emptyState()
                      else
                        _transactionList(
                            snapshot.data!.docs.take(5).toList()),
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

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _header(User? currentUser) {
    Widget headerRow(String name) {
      final firstName = name.trim().split(' ').first;
      return Row(
        children: [
          Container(
            height: 48,
            width: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.35)),
            ),
            child: Text(_initials(name),
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $firstName',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                const SizedBox(height: 2),
                Text('Manage your finances smarter',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ],
            ),
          ),
          _bell(),
        ],
      );
    }

    if (currentUser == null) return headerRow('Student');

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        String userName = 'Student';
        if (userSnapshot.hasData && userSnapshot.data!.data() != null) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          userName = (userData['name'] ?? 'Student').toString();
        }
        return headerRow(userName);
      },
    );
  }

  Widget _bell() {
    return GestureDetector(
      onTap: () => _push(context, const ProfileScreen()),
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadow.soft,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded,
                color: AppColors.primary),
            Positioned(
              top: 13,
              right: 14,
              child: Container(
                height: 8,
                width: 8,
                decoration: const BoxDecoration(
                    color: AppColors.danger, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  // ---------------------------------------------------------------------------
  // Balance card
  // ---------------------------------------------------------------------------
  Widget _balanceCard(double balance) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.heroGlow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.primary.withOpacity(0.30),
                      AppColors.primary.withOpacity(0.0),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Available balance',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13.5)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              setState(() => hideBalance = !hideBalance),
                          child: Icon(
                            hideBalance
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white60,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Text(
                        hideBalance ? Money.hidden : Money.naira(balance),
                        key: ValueKey(hideBalance),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text));

  // ---------------------------------------------------------------------------
  // Quick actions
  // ---------------------------------------------------------------------------
  Widget _quickActionsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _quickAction(
                label: 'Transfer',
                icon: Icons.north_east_rounded,
                onTap: () => _push(context, const TransferScreen()))),
        Expanded(
            child: _quickAction(
                label: 'Airtime',
                icon: Icons.smartphone_rounded,
                onTap: () => _push(context, const AirtimeScreen()))),
        Expanded(
            child: _quickAction(
                label: 'Data',
                icon: Icons.wifi_rounded,
                onTap: () => _push(context, const DataScreen()))),
        Expanded(
            child: _quickAction(
                label: 'Lock',
                icon: Icons.lock_rounded,
                iconColor: AppColors.primary,
                onTap: () => _push(context, const LockMoneyScreen()))),
        Expanded(
            child: _quickAction(
                label: 'Card',
                icon: Icons.credit_card_rounded,
                onTap: () => _push(context, const VirtualCardScreen()))),
      ],
    );
  }

  Widget _quickAction({
    required String label,
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            height: 58,
            width: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppShadow.soft,
            ),
            child: Icon(icon, color: iconColor ?? AppColors.text, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Daily budget card
  // ---------------------------------------------------------------------------
  Widget _budgetCard({
    required double savedBudget,
    required double spentToday,
    required double progress,
    required bool overSpending,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: [
          _budgetRow(
            label: 'Daily budget',
            amount: savedBudget,
            progress: savedBudget > 0 ? 1.0 : 0.0,
            color: AppColors.primary,
          ),
          const SizedBox(height: 18),
          _budgetRow(
            label: 'Spent today',
            amount: spentToday,
            progress: progress,
            color: overSpending ? AppColors.danger : AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _budgetRow({
    required String label,
    required double amount,
    required double progress,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            Text(Money.naira(amount),
                style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              Container(
                height: 8,
                width: c.maxWidth,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Container(
                height: 8,
                width: (c.maxWidth * progress).clamp(0.0, c.maxWidth),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Recent transactions
  // ---------------------------------------------------------------------------
  Widget _transactionList(List<QueryDocumentSnapshot> docs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          for (int i = 0; i < docs.length; i++) ...[
            _txnTile(docs[i].data() as Map<String, dynamic>),
            if (i != docs.length - 1)
              Divider(height: 22, color: AppColors.border.withOpacity(0.6)),
          ],
        ],
      ),
    );
  }

  Widget _txnTile(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    final category = (data['category'] ?? 'Transaction').toString();
    final amount = _toDouble(data['amount']);
    final date = DateTime.tryParse((data['date'] ?? '').toString());
    final income = type == 'income';
    final color = income ? AppColors.success : AppColors.danger;

    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.16),
            shape: BoxShape.circle,
          ),
          child: income
              ? const Text('\u20A6',
                  style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w900,
                      fontSize: 18))
              : Icon(_txnIcon(category), color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5)),
              const SizedBox(height: 3),
              Text('${income ? 'Income' : 'Expense'} \u00b7 ${_dateLabel(date)}',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text('${income ? '+' : '-'}${Money.naira(amount)}',
            style: TextStyle(
                color: income ? AppColors.success : AppColors.text,
                fontWeight: FontWeight.w800,
                fontSize: 14.5)),
      ],
    );
  }

  IconData _txnIcon(String category) {
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('meal')) {
      return Icons.restaurant_rounded;
    }
    if (c.contains('transfer')) return Icons.north_east_rounded;
    if (c.contains('airtime')) return Icons.smartphone_rounded;
    if (c.contains('data')) return Icons.wifi_rounded;
    if (c.contains('lock')) return Icons.lock_rounded;
    if (c.contains('saving') || c.contains('goal')) {
      return Icons.savings_rounded;
    }
    if (c.contains('transport') || c.contains('uber') || c.contains('bolt')) {
      return Icons.directions_car_rounded;
    }
    if (c.contains('shop')) return Icons.shopping_bag_rounded;
    if (c.contains('card')) return Icons.credit_card_rounded;
    return Icons.receipt_long_rounded;
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final time = '$h:$m $ampm';
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    if (sameDay(date, now)) return 'Today, $time';
    if (sameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday, $time';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, $time';
  }

  Widget _emptyState() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, color: AppColors.muted, size: 30),
            const SizedBox(height: 10),
            Text('No transactions yet',
                style: TextStyle(
                    color: AppColors.muted, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _errorState() => Center(
        child: Text('Something went wrong',
            style: TextStyle(color: AppColors.muted)),
      );

  // ---------------------------------------------------------------------------
  // Bottom navigation
  // ---------------------------------------------------------------------------
  Widget _bottomNav(BuildContext context) => LiquidNavBar(
        currentIndex: 0,
        onCenterTap: () => _push(context, const AddMoneyScreen()),
        onTap: (i) {
          switch (i) {
            case 1:
              _push(context, const AnalyticsScreen());
              break;
            case 2:
              _push(context, const BudgetSetupScreen());
              break;
            case 3:
              _push(context, const ProfileScreen());
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
