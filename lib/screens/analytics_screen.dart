import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/liquid_nav_bar.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'budget_setup_screen.dart';
import 'add_money_screen.dart';

enum _Period { day, week, month }

/// STASH — Analytics (black liquid UI).
///
/// Reads the live transactions stream and lets the user switch between
/// Day / Week / Month. Shows total spend for the chosen period, a set of
/// insight cards (income, net flow, average/day, biggest expense), a weekly
/// spending bar chart, and a per-category breakdown. All Firebase logic
/// (FirestoreService().getTransactions) is preserved.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _Period _period = _Period.week;

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  // Dot palette for the category breakdown (mirrors the reference design).
  static const List<Color> _dotColors = [
    AppColors.success,
    AppColors.primary,
    AppColors.danger,
    Color(0xFF8C8F84),
  ];

  DateTime get _weekStart {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return midnight.subtract(Duration(days: now.weekday - 1)); // Monday
  }

  bool _inPeriod(DateTime date) {
    final now = DateTime.now();
    switch (_period) {
      case _Period.day:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case _Period.week:
        final start = _weekStart;
        final end = start.add(const Duration(days: 7));
        return !date.isBefore(start) && date.isBefore(end);
      case _Period.month:
        return date.year == now.year && date.month == now.month;
    }
  }

  String get _periodWord {
    switch (_period) {
      case _Period.day:
        return 'today';
      case _Period.week:
        return 'this week';
      case _Period.month:
        return 'this month';
    }
  }

  /// Number of days elapsed in the current period, used for the daily average.
  int get _daysElapsed {
    final now = DateTime.now();
    switch (_period) {
      case _Period.day:
        return 1;
      case _Period.week:
        return now.weekday; // Mon = 1 .. Sun = 7
      case _Period.month:
        return now.day;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirestoreService().getTransactions(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Something went wrong',
                    style: TextStyle(color: AppColors.muted)),
              );
            }

            double totalSpent = 0;
            double periodIncome = 0;
            double biggestExpense = 0;
            String biggestExpenseCat = '';
            final Map<String, double> categoryTotals = {};
            final List<double> weekBars = List<double>.filled(7, 0);
            final weekStart = _weekStart;

            if (snapshot.hasData) {
              for (final doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) continue;

                final type = (data['type'] ?? '').toString();
                final amount = _toDouble(data['amount']);
                final category = (data['category'] ?? 'Other').toString();
                final date = DateTime.tryParse((data['date'] ?? '').toString());
                if (date == null) continue;

                // Income only contributes to the period income insight.
                if (type == 'income') {
                  if (_inPeriod(date)) periodIncome += amount;
                  continue;
                }
                if (type != 'expense') continue;

                // Per-period totals + category breakdown + biggest expense.
                if (_inPeriod(date)) {
                  totalSpent += amount;
                  categoryTotals[category] =
                      (categoryTotals[category] ?? 0) + amount;
                  if (amount > biggestExpense) {
                    biggestExpense = amount;
                    biggestExpenseCat = category;
                  }
                }

                // Weekly bar chart always reflects the current week.
                final dayMidnight = DateTime(date.year, date.month, date.day);
                final diff = dayMidnight.difference(weekStart).inDays;
                if (diff >= 0 && diff < 7) {
                  weekBars[diff] += amount;
                }
              }
            }

            final sorted = categoryTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final avgPerDay = _daysElapsed > 0 ? totalSpent / _daysElapsed : 0.0;
            final net = periodIncome - totalSpent;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analytics',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 18),
                  _periodSelector(),
                  const SizedBox(height: 20),
                  _spendCard(totalSpent, weekBars),
                  const SizedBox(height: 20),
                  _insightsGrid(
                      periodIncome, net, avgPerDay, biggestExpense,
                      biggestExpenseCat),
                  const SizedBox(height: 26),
                  Text('By category',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  _categoryCard(sorted, totalSpent),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _bottomNav(context),
    );
  }

  // ---- Period selector (Day / Week / Month) ----
  Widget _periodSelector() {
    Widget seg(String label, _Period value) {
      final selected = _period == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _period = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Text(label,
                style: TextStyle(
                    color: selected ? AppColors.onAccent : AppColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          seg('Day', _Period.day),
          seg('Week', _Period.week),
          seg('Month', _Period.month),
        ],
      ),
    );
  }

  // ---- Total spend card + weekly bar chart ----
  Widget _spendCard(double totalSpent, List<double> weekBars) {
    final maxVal = weekBars.fold<double>(0, (m, v) => v > m ? v : m);
    int maxIndex = 0;
    for (int i = 0; i < weekBars.length; i++) {
      if (weekBars[i] >= weekBars[maxIndex]) maxIndex = i;
    }
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total spent $_periodWord',
              style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
          const SizedBox(height: 8),
          Text(Money.naira(totalSpent),
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1)),
          const SizedBox(height: 22),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                              begin: 0,
                              end: maxVal <= 0 ? 0 : weekBars[i] / maxVal),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, _) => Container(
                            height: 10 + t * 86,
                            width: 16,
                            decoration: BoxDecoration(
                              color: (i == maxIndex && maxVal > 0)
                                  ? AppColors.primary
                                  : Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: (i == maxIndex && maxVal > 0)
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withOpacity(0.35),
                                        blurRadius: 14,
                                        spreadRadius: -2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(labels[i],
                            style: TextStyle(
                                color: i == maxIndex
                                    ? AppColors.text
                                    : AppColors.muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Insight cards (income / net flow / avg per day / biggest expense) ----
  Widget _insightsGrid(double income, double net, double avgPerDay,
      double biggest, String biggestCat) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _insightCard('Income $_periodWord', Money.naira(income),
                  Icons.south_west_rounded, AppColors.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _insightCard('Net flow', Money.naira(net),
                  Icons.swap_vert_rounded,
                  net >= 0 ? AppColors.success : AppColors.danger),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _insightCard('Avg / day', Money.naira(avgPerDay),
                  Icons.today_rounded, AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _insightCard(
                'Biggest expense',
                biggest > 0 ? Money.naira(biggest) : '\u2014',
                Icons.trending_up_rounded,
                AppColors.danger,
                caption: biggest > 0 ? biggestCat : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _insightCard(String label, String value, IconData icon, Color color,
      {String? caption}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
          const SizedBox(height: 3),
          Text(caption ?? label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ---- Category breakdown ----
  Widget _categoryCard(
      List<MapEntry<String, double>> sorted, double totalSpent) {
    if (sorted.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadow.soft,
        ),
        child: Text('No spending recorded for $_periodWord yet.',
            style: TextStyle(color: AppColors.muted)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Container(
                    height: 12,
                    width: 12,
                    decoration: BoxDecoration(
                      color: _dotColors[i % _dotColors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(sorted[i].key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ),
                  if (totalSpent > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                          '${((sorted[i].value / totalSpent) * 100).round()}%',
                          style: TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5)),
                    ),
                  Text(Money.naira(sorted[i].value),
                      style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5)),
                ],
              ),
            ),
            if (i != sorted.length - 1)
              Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  // ---- Bottom navigation (Analytics = index 1) ----
  void _replace(Widget page) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _bottomNav(BuildContext context) => LiquidNavBar(
        currentIndex: 1,
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
            case 2:
              _replace(const BudgetSetupScreen());
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
