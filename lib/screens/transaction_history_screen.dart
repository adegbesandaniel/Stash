import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import 'receipt_screen.dart';

/// STASH — Transaction History (black liquid UI).
///
/// Filter chips (All / Income / Expense / Transfer) + day-grouped list.
/// Tapping any row opens the branded receipt. Firestore stream is unchanged.
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  static const List<String> _filters = ['All', 'Income', 'Expense', 'Transfer'];
  String _filter = 'All';

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static const Color _blue = Color(0xFF4D8DFF);

  bool _matches(String type, String category) {
    switch (_filter) {
      case 'Income':
        return type == 'income';
      case 'Expense':
        return type == 'expense' &&
            !category.toLowerCase().contains('transfer');
      case 'Transfer':
        return category.toLowerCase().contains('transfer');
      default:
        return true;
    }
  }

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd = DateTime(d.year, d.month, d.day);
    final diff = today.difference(dd).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return '${_months[d.month - 1]} ${d.day}, ${d.year}'.toUpperCase();
  }

  // Returns (icon-or-null, glyph-or-null, color) for a transaction.
  (IconData?, String?, Color) _visual(String type, String category) {
    final c = category.toLowerCase();
    if (type == 'income') return (null, '\u20A6', AppColors.success);
    if (c.contains('transfer')) {
      return (Icons.north_east_rounded, null, AppColors.primary);
    }
    if (c.contains('food') || c.contains('meal')) {
      return (Icons.restaurant_rounded, null, AppColors.danger);
    }
    if (c.contains('data')) return (Icons.bar_chart_rounded, null, _blue);
    if (c.contains('airtime')) {
      return (Icons.phone_android_rounded, null, _blue);
    }
    if (c.contains('lock')) return (Icons.lock_rounded, null, AppColors.primary);
    return (Icons.north_east_rounded, null, AppColors.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _header(context),
            ),
            const SizedBox(height: 18),
            _filterBar(),
            const SizedBox(height: 8),
            Expanded(child: _list()),
          ],
        ),
      ),
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
        Text('History',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
      ],
    );
  }

  // ---- Filter chips ----
  Widget _filterBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final f = _filters[i];
          final selected = _filter == f;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border),
              ),
              child: Text(f,
                  style: TextStyle(
                      color: selected ? AppColors.onAccent : AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5)),
            ),
          );
        },
      ),
    );
  }

  // ---- List ----
  Widget _list() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService().getTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('No transactions yet.',
                style: TextStyle(color: AppColors.muted)),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = (data['type'] ?? 'expense').toString();
          final category = (data['category'] ?? '').toString();
          return _matches(type, category);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Text('No $_filter transactions.',
                style: TextStyle(color: AppColors.muted)),
          );
        }

        final items = <Widget>[];
        String? lastDay;
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final dateStr = (data['date'] ?? '').toString();
          final date = DateTime.tryParse(dateStr) ?? DateTime.now();
          final dayLabel = _dayLabel(date);
          if (dayLabel != lastDay) {
            lastDay = dayLabel;
            items.add(Padding(
              padding: EdgeInsets.only(
                  top: items.isEmpty ? 4 : 18, bottom: 10, left: 4),
              child: Text(dayLabel,
                  style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8)),
            ));
          }
          items.add(_tile(doc.id, data, date));
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
          children: items,
        );
      },
    );
  }

  Widget _tile(String id, Map<String, dynamic> data, DateTime date) {
    final type = (data['type'] ?? 'expense').toString();
    final isIncome = type == 'income';
    final category = (data['category'] ?? 'Transaction').toString();
    final note = (data['note'] ?? '').toString();
    final rawAmount = data['amount'];
    final amount = rawAmount is num ? rawAmount.toDouble() : 0.0;
    final visual = _visual(type, category);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(
            type: type,
            category: category,
            amount: amount,
            note: note,
            date: date,
            reference: 'STASH-$id',
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadow.soft,
        ),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visual.$3.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: visual.$1 != null
                  ? Icon(visual.$1, color: visual.$3, size: 22)
                  : Text(visual.$2 ?? '',
                      style: TextStyle(
                          color: visual.$3,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text)),
                  const SizedBox(height: 4),
                  Text(_time(date),
                      style: TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'}${Money.naira(amount)}',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: isIncome ? AppColors.success : AppColors.text),
            ),
          ],
        ),
      ),
    );
  }
}
