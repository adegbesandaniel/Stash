import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_nav_bar.dart';
import 'login_screen.dart';
import 'security_screen.dart';
import 'referrals_screen.dart';
import 'dashboard_screen.dart';
import 'analytics_screen.dart';
import 'budget_setup_screen.dart';
import 'add_money_screen.dart';

/// STASH — Profile (black liquid UI).
///
/// Preserves all existing logic: the users/{uid} document stream, logout via
/// AuthService(), session-unlock reset, and Security screen navigation.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loggingOut = false;

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

  void _comingSoon(String title) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$title coming soon'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await AuthService().logout();
      // Clear the unlock session so the lock screen is enforced next login.
      SecurityService.unlockedThisSession = false;
    } catch (_) {
      if (mounted) {
        setState(() => _loggingOut = false);
        _showError('Could not log out. Try again.');
      }
      return;
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: user == null
            ? _emptyState()
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _errorState();
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }

                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final name = (data?['name'] as Object?)
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true
                      ? (data!['name'] as Object).toString().trim()
                      : 'Student';
                  final email = (data?['email'] as Object?)?.toString() ??
                      user.email ??
                      '';
                  final verified = user.emailVerified;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
                    child: Column(
                      children: [
                        _avatar(name),
                        const SizedBox(height: 16),
                        Text(name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(email,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 13.5)),
                        const SizedBox(height: 12),
                        _verifiedPill(verified),
                        const SizedBox(height: 28),
                        _sectionLabel('Account'),
                        const SizedBox(height: 12),
                        _groupCard([
                          _row(Icons.person_outline_rounded,
                              'Personal information',
                              onTap: () => _comingSoon('Personal information')),
                          _row(Icons.credit_card_outlined, 'Cards & accounts',
                              onTap: () => _comingSoon('Cards & accounts')),
                          _row(Icons.card_giftcard_rounded, 'Refer & earn',
                              onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ReferralsScreen()),
                                  )),
                        ]),
                        const SizedBox(height: 24),
                        _sectionLabel('Preferences'),
                        const SizedBox(height: 12),
                        _groupCard([
                          _row(Icons.notifications_none_rounded,
                              'Notifications',
                              onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const SecurityScreen()),
                                  )),
                          _row(Icons.contrast_rounded, 'Appearance',
                              onTap: () => _comingSoon('Appearance')),
                          _row(Icons.lock_outline_rounded, 'Security',
                              onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const SecurityScreen()),
                                  )),
                          _row(Icons.help_outline_rounded, 'Help & support',
                              onTap: () => _comingSoon('Help & support')),
                        ]),
                        const SizedBox(height: 28),
                        _logoutButton(),
                      ],
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: _bottomNav(context),
    );
  }

  // ---- Avatar ----
  Widget _avatar(String name) {
    return Container(
      height: 104,
      width: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 26,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Text(_initials(name),
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 36,
              fontWeight: FontWeight.w900)),
    );
  }

  // ---- Verified pill ----
  Widget _verifiedPill(bool verified) {
    final color = verified ? AppColors.success : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verified ? Icons.verified_rounded : Icons.info_outline_rounded,
              color: color, size: 16),
          const SizedBox(width: 6),
          Text(verified ? 'Verified account' : 'Email not verified',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ],
      ),
    );
  }

  // ---- Section helpers ----
  Widget _sectionLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w900)),
      );

  Widget _groupCard(List<Widget> rows) {
    final children = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(Divider(
            height: 1, color: AppColors.border, indent: 64, endIndent: 8));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.soft,
      ),
      child: Column(children: children),
    );
  }

  Widget _row(IconData icon, String title, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }

  // ---- Logout ----
  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dangerSoft,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        onPressed: _loggingOut ? null : _logout,
        child: _loggingOut
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.danger),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.logout_rounded,
                      color: AppColors.danger, size: 20),
                  SizedBox(width: 10),
                  Text('Logout',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                ],
              ),
      ),
    );
  }

  // ---- States ----
  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 40, color: AppColors.muted),
            const SizedBox(height: 14),
            Text('No user logged in',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.muted),
            const SizedBox(height: 14),
            Text('Could not load your profile',
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
      ),
    );
  }

  // ---- Bottom navigation (Profile = index 3) ----
  void _replace(Widget page) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _bottomNav(BuildContext context) => LiquidNavBar(
        currentIndex: 3,
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
            case 2:
              _replace(const BudgetSetupScreen());
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
