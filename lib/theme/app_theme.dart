import 'package:flutter/material.dart';

/// Global theme controller. STASH ships a single dark "black liquid" theme;
/// the notifier is kept for the in-app toggle but the palette is dark-first.
class ThemeController {
  ThemeController._();
  static final ValueNotifier<bool> isDark = ValueNotifier<bool>(true);
  static void setDark(bool value) => isDark.value = value;
  static void toggle() => isDark.value = !isDark.value;
}

/// STASH design tokens — black liquid UI with a single acid-lime accent.
class AppColors {
  AppColors._();

  // ---- Brand accent (acid-lime) ----
  static const Color primary = Color(0xFFC8FF4D); // primary buttons, progress, nav, +
  static const Color secondary = Color(0xFFB6F23A); // lime variant for gradients
  static const Color success = Color(0xFF22C77E); // income / success
  static const Color danger = Color(0xFFFF5C73); // expense / alert (coral)

  // Lime accent surface used for primary buttons, FAB and active states.
  static const Color hero = Color(0xFFC8FF4D);

  // Dark ink for text/icons that sit ON the lime accent.
  static const Color onAccent = Color(0xFF0A0A0C);

  // ---- Surfaces (single dark theme; getters kept for API compatibility) ----
  static Color get background => const Color(0xFF0A0A0C); // near-black canvas
  static Color get card => const Color(0xFF1B1B21); // dark charcoal cards
  static Color get border => const Color(0xFF2A2B33);
  static Color get text => const Color(0xFFF4F6EC); // near-white
  static Color get muted => const Color(0xFF8C8F84);

  // ---- Soft tints ----
  static Color get primarySoft => primary.withOpacity(0.16);
  static Color get successSoft => success.withOpacity(0.18);
  static Color get dangerSoft => danger.withOpacity(0.18);

  // ---- Liquid (glassmorphism) nav surfaces ----
  static Color get glass => Colors.white.withOpacity(0.06);
  static Color get glassBorder => Colors.white.withOpacity(0.12);

  // ---- Gradients ----
  // Charcoal hero card (balances / amounts) — soft, no harsh edges.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF24252C), Color(0xFF17181D), Color(0xFF0F1012)],
    stops: [0.0, 0.55, 1.0],
  );

  // Lime accent gradient (FAB / highlights). Name kept for compatibility.
  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB6F23A), Color(0xFFC8FF4D)],
  );
}

class AppRadius {
  AppRadius._();
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 30;
  static const double pill = 999;
}

class AppShadow {
  AppShadow._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get hero => [
        BoxShadow(
          color: Colors.black.withOpacity(0.45),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ];

  /// Hero treatment: a charcoal card lifted by a soft acid-lime glow.
  static List<BoxShadow> get heroGlow => [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.22),
          blurRadius: 34,
          spreadRadius: -8,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.40),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];
}

/// Builds Material ThemeData. STASH uses one dark scheme for both slots.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base();
  static ThemeData dark() => _base();

  static ThemeData _base() {
    const bg = Color(0xFF0A0A0C);
    const txt = Color(0xFFF4F6EC);
    const card = Color(0xFF1B1B21);

    final base = ThemeData(brightness: Brightness.dark);
    return base.copyWith(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      primaryColor: AppColors.primary,
      canvasColor: card,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: AppColors.onAccent,
        surface: card,
        onSurface: txt,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: txt, displayColor: txt, fontFamily: 'Inter'),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onAccent,
        ),
      ),
    );
  }
}
