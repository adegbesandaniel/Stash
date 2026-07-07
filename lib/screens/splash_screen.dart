import 'dart:async';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../services/security_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'lock_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _glow;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textSlide;

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // ---- Fade + zoom-in entrance (pure Flutter, no packages) ----
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _glow = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.85, curve: Curves.easeOut),
    );
    _textOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.95, curve: Curves.easeOut),
    );
    _textSlide = Tween<double>(begin: 22.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // ---- Routing (unchanged logic): wait, then route by auth + app-lock ----
    _navTimer = Timer(const Duration(milliseconds: 2400), _route);
  }

  Future<void> _route() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      bool locked = false;
      try {
        final security = SecurityService();
        locked = await security.isAppLockEnabled() && await security.hasPin();
      } catch (_) {}
      if (!mounted) return;
      if (locked && !SecurityService.unlockedThisSession) {
        _go(const LockScreen());
        return;
      }
      _go(const DashboardScreen());
      return;
    }
    _go(const OnboardingScreen());
  }

  void _go(Widget page) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: _logo(),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Opacity(
                      opacity: _textOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('STASH',
                                style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3)),
                            const SizedBox(height: 10),
                            Text('Manage your finances smarter',
                                style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: Column(
              children: [
                const _LoadingDots(),
                const SizedBox(height: 18),
                Opacity(
                  opacity: 0.5,
                  child: Text('v1.0.0',
                      style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo() {
    final glow = _glow.value;
    return Container(
      height: 112,
      width: 112,
      decoration: BoxDecoration(
        gradient: AppColors.purpleGradient, // acid-lime accent gradient
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35 * glow),
            blurRadius: 46 * glow,
            spreadRadius: 2 * glow,
          ),
        ],
      ),
      child: const Center(
        child: Text('S',
            style: TextStyle(
                color: AppColors.onAccent,
                fontSize: 58,
                fontWeight: FontWeight.w900)),
      ),
    );
  }
}

/// A subtle three-dot "breathing" loader shown while the splash routes.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final t = (_c.value + i * 0.2) % 1.0;
            final wave = (0.5 - (t - 0.5).abs()) * 2; // 0 -> 1 -> 0
            final opacity = 0.35 + 0.65 * wave;
            final scale = 0.85 + 0.35 * wave;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  height: 9,
                  width: 9,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
