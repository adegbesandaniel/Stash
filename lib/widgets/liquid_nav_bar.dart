import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A single destination in the liquid nav bar.
class LiquidNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const LiquidNavItem({
    required this.icon,
    IconData? activeIcon,
    required this.label,
  }) : activeIcon = activeIcon ?? icon;
}

/// STASH signature "liquid" navigation bar.
///
/// A floating, frosted-glass pill that hovers above the bottom edge. It has
/// four tab slots (2 left, 2 right) wrapped around a raised purple center
/// "+" action button. The active tab shows a glowing purple highlight that
/// animates (the "liquid" feel) as it slides between tabs.
class LiquidNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;

  /// Exactly four items: indexes 0,1 sit left of center, 2,3 sit right.
  final List<LiquidNavItem> items;

  const LiquidNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCenterTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4,
        'LiquidNavBar expects exactly 4 items around the center button');
    final dark = ThemeController.isDark.value;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.glassBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(dark ? 0.45 : 0.12),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _slot(0),
                  _slot(1),
                  _centerButton(),
                  _slot(2),
                  _slot(3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _slot(int i) {
    final item = items[i];
    final selected = currentIndex == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: selected ? 18 : 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withOpacity(0.16)
                  : Colors.transparent,
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                key: ValueKey(selected),
                color: selected ? AppColors.primary : AppColors.muted,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _centerButton() {
    return GestureDetector(
      onTap: onCenterTap,
      child: Container(
        width: 58,
        alignment: Alignment.center,
        child: Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.secondary, AppColors.primary],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.55),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: AppColors.onAccent, size: 30),
        ),
      ),
    );
  }
}
