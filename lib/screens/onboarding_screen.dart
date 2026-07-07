import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'login_screen.dart';

/// A single onboarding slide.
class _OnboardPage {
  final String emoji;
  final String title;
  final String subtitle;
  const _OnboardPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

const List<_OnboardPage> _pages = [
  _OnboardPage(
    emoji: '\u{1F4B8}',
    title: 'Manage your finances smarter',
    subtitle:
        'Track every expense, set daily budgets, and stay in control of your student money.',
  ),
  _OnboardPage(
    emoji: '\u{1F3AF}',
    title: 'Save towards what matters',
    subtitle:
        'Set goals, lock funds, and watch your savings grow with smart automated tools.',
  ),
  _OnboardPage(
    emoji: '\u{1F4CA}',
    title: 'See where your money goes',
    subtitle:
        'Beautiful analytics and a virtual card to spend, send, and manage with confidence.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();
  late final AnimationController _float;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Gentle, continuous float applied to the hero emoji for liveliness.
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _float.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_index > 0) {
      _controller.previousPage(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ---- Top bar: brand mark + Skip ----
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 10, 0),
              child: Row(
                children: [
                  Text('STASH',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                  const Spacer(),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isLast ? 0 : 1,
                    child: TextButton(
                      onPressed: isLast ? null : _finish,
                      child: Text('Skip',
                          style: TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _page(_pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => _dot(i == _index)),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  if (_index > 0) ...[
                    Expanded(child: _backButton()),
                    const SizedBox(width: 14),
                  ],
                  Expanded(child: _nextButton(isLast)),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }

  Widget _page(_OnboardPage p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadow.heroGlow,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft acid-lime radial highlight behind the emoji.
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.20),
                            AppColors.primary.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _float,
                      builder: (context, child) {
                        final dy = (_float.value - 0.5) * 16; // -8 .. 8
                        return Transform.translate(
                          offset: Offset(0, dy),
                          child: child,
                        );
                      },
                      child: Text(p.emoji, style: const TextStyle(fontSize: 96)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(p.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8)),
          const SizedBox(height: 14),
          Text(p.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.muted, fontSize: 15, height: 1.6)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _dot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: active ? 24 : 8,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.border,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  Widget _backButton() {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: AppColors.border)),
        ),
        onPressed: _back,
        child: Text('Back',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _nextButton(bool isLast) {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.hero,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        onPressed: _next,
        child: Text(isLast ? 'Get Started' : 'Next',
            style: const TextStyle(
                color: Color(0xFF0A0A0C),
                fontSize: 16,
                fontWeight: FontWeight.w900)),
      ),
    );
  }
}
