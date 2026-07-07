import 'package:flutter/material.dart';

import '../../services/goal_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../receipt_screen.dart';

/// Shows a premium animated "success" popup after a transaction completes.
Future<void> showStashSuccess(
  BuildContext context, {
  required String title,
  required String message,
  double? amount,
  String? footnote,
  ReceiptScreen? receipt,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (_) => _SuccessDialog(
      title: title,
      message: message,
      amount: amount,
      footnote: footnote,
      receipt: receipt,
    ),
  );
}

/// Records a transaction's after-effects: applies an Auto-Save round-up (when
/// enabled and the transaction is an expense), builds a shareable receipt
/// (when transaction details are provided), then shows the success popup.
Future<void> completeTransaction(
  BuildContext context, {
  required String title,
  required String message,
  required double amount,
  required String type, // 'income' | 'expense' | 'lock'
  String? category,
  String? note,
  String? reference,
}) async {
  String? footnote;
  if (type == 'expense' && amount > 0) {
    try {
      final enabled = await SettingsService().loadRoundUps();
      if (enabled) {
        final rounded = (amount / 100).ceil() * 100;
        final change = rounded - amount;
        if (change > 0) {
          final err = await GoalService().addRoundUp(change);
          if (err == null) {
            footnote =
                '${Money.naira(change)} auto-saved to your Round-ups vault';
          }
        }
      }
    } catch (_) {}
  }
  if (!context.mounted) return;

  // Build a receipt for income/expense transactions when details are given.
  ReceiptScreen? receipt;
  if (category != null && (type == 'income' || type == 'expense')) {
    receipt = ReceiptScreen(
      type: type,
      category: category,
      amount: amount,
      note: note ?? '',
      date: DateTime.now(),
      reference: reference ??
          'STASH-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  await showStashSuccess(
    context,
    title: title,
    message: message,
    amount: amount,
    footnote: footnote,
    receipt: receipt,
  );
}

class _SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final double? amount;
  final String? footnote;
  final ReceiptScreen? receipt;

  const _SuccessDialog({
    required this.title,
    required this.message,
    this.amount,
    this.footnote,
    this.receipt,
  });

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadow.heroGlow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                height: 78,
                width: 78,
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 44),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text),
            ),
            if (amount != null) ...[
              const SizedBox(height: 6),
              Text(
                Money.naira(amount!),
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -1),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
            if (footnote != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.savings_rounded,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        footnote!,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (r != null) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  onPressed: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push(
                        MaterialPageRoute(builder: (_) => r));
                  },
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('View receipt',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Done',
                    style: TextStyle(
                        color: Color(0xFF0A0A0C),
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
