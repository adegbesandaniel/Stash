import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_theme.dart';

/// STASH — Refer & earn (black liquid UI).
///
/// Generates a stable, shareable referral code from the signed-in user's UID
/// and lets them copy the code or a ready-made invite message. No backend
/// dependency: sharing uses the system clipboard so it works everywhere.
class ReferralsScreen extends StatelessWidget {
  const ReferralsScreen({super.key});

  String get _code {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'STUDENT';
    final base = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final slice =
        base.length >= 6 ? base.substring(0, 6) : base.padRight(6, 'X');
    return 'STASH-$slice';
  }

  String get _inviteText =>
      'Join me on STASH \u2014 the student finance app that helps you budget, '
      'save and spend smarter. Use my code $_code when you sign up and we both '
      'get a reward! \ud83c\udf89';

  void _copy(BuildContext context, String text, String toast) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(toast),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: true,
        title: const Text('Refer & earn',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hero(context),
            const SizedBox(height: 24),
            Text('How it works', style: _label()),
            const SizedBox(height: 12),
            _step(1, 'Share your code',
                'Send your unique code to friends and classmates.'),
            _step(2, 'They sign up',
                'Your friend creates a STASH account using your code.'),
            _step(3, 'You both earn',
                'You each get a \u20a6500 wallet bonus once they fund their wallet.'),
            const SizedBox(height: 24),
            Text('Student perks', style: _label()),
            const SizedBox(height: 12),
            _perk(Icons.savings_rounded, '\u20a6500 per friend',
                'Earn a bonus for every friend who joins and funds.'),
            _perk(Icons.workspace_premium_rounded, 'Unlock premium',
                'Refer 5 friends to unlock premium themes & insights.'),
            _perk(Icons.local_activity_rounded, 'Exclusive deals',
                'Access student-only discounts from partner brands.'),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                onPressed: () => _copy(context, _inviteText,
                    'Invite copied \u2014 paste it anywhere to share.'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.ios_share_rounded,
                        size: 20, color: Color(0xFF0A0A0C)),
                    SizedBox(width: 10),
                    Text('Share invite',
                        style: TextStyle(
                            color: Color(0xFF0A0A0C),
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _label() => TextStyle(
      color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900);

  Widget _hero(BuildContext context) {
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
          Row(
            children: const [
              Icon(Icons.card_giftcard_rounded,
                  color: AppColors.primary, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text('Invite friends,\nearn rewards',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.2)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('YOUR CODE',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(_code,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                ),
                GestureDetector(
                  onTap: () => _copy(context, _code, 'Code copied!'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.copy_rounded,
                            size: 16, color: Color(0xFF0A0A0C)),
                        SizedBox(width: 6),
                        Text('Copy',
                            style: TextStyle(
                                color: Color(0xFF0A0A0C),
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(int n, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: Text('$n',
                style: const TextStyle(
                    color: AppColors.onAccent, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        color: AppColors.muted, fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _perk(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.soft,
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        color: AppColors.muted, fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
