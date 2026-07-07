import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../utils/money.dart';

/// Shared premium form used by Add Income and Add Expense.
/// Renders a gradient hero, a live amount field, selectable category chips,
/// a note field, and a loading-aware save button.
class PremiumMoneyForm extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final String selectedValue;
  final List<String> values;
  final String sectionLabel;
  final String buttonText;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSave;

  const PremiumMoneyForm({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.amountController,
    required this.noteController,
    required this.selectedValue,
    required this.values,
    required this.sectionLabel,
    required this.buttonText,
    required this.isLoading,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  AnimatedBuilder(
                    animation: amountController,
                    builder: (context, _) {
                      final amount =
                          double.tryParse(amountController.text) ?? 0;
                      return Text(Money.naira(amount),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1));
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white70, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadow.soft,
              ),
              child: TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  labelStyle: TextStyle(color: AppColors.muted),
                  prefixText: '₦ ',
                  prefixIcon:
                      Icon(Icons.payments_outlined, color: AppColors.primary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(18),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(sectionLabel,
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: AppColors.text)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final v in values)
                  GestureDetector(
                    onTap: () => onChanged(v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selectedValue == v
                            ? AppColors.primary
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: AppShadow.soft,
                      ),
                      child: Text(v,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: selectedValue == v
                                  ? Colors.white
                                  : AppColors.text)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadow.soft,
              ),
              child: TextField(
                controller: noteController,
                maxLines: 4,
                maxLength: 140,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Note',
                  hintText: 'Optional note',
                  labelStyle: TextStyle(color: AppColors.muted),
                  prefixIcon:
                      Icon(Icons.note_alt_outlined, color: AppColors.primary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(18),
                ),
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hero,
                  disabledBackgroundColor: AppColors.hero.withOpacity(0.7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                onPressed: onSave,
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Color(0xFF0A0A0C)))
                    : Text(buttonText,
                        style: const TextStyle(
                            color: Color(0xFF0A0A0C),
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
