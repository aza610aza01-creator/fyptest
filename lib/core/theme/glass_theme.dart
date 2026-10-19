import 'package:flutter/material.dart';

/// Material 3 & Glassmorphism theme builder with lime green accent (0xFF9ED756).
class GlassTheme {
  GlassTheme._();

  static const Color limeAccent = Color(0xFF9ED756);
  static const Color darkNavyBgTop = Color(0xFF0A141D);
  static const Color darkGreenBgBottom = Color(0xFF102820);
  static const Color lightBgTop = Color(0xFFF3F8EE);
  static const Color lightBgBottom = Color(0xFFE2EFE8);

  static ThemeData buildTheme({
    required Brightness brightness,
    required bool glassEnabled,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: limeAccent,
      brightness: brightness,
      primary: isDark ? limeAccent : const Color(0xFF4C7B1E),
      secondary: isDark ? const Color(0xFF72D6A4) : const Color(0xFF1F6E50),
      surface: isDark ? const Color(0xFF12212B) : const Color(0xFFFFFFFF),
    );

    final cardColor = glassEnabled
        ? (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.72))
        : (isDark ? const Color(0xFF162632) : Colors.white);

    final inputFillColor = glassEnabled
        ? (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.78))
        : (isDark ? const Color(0xFF1C2F3D) : const Color(0xFFF5F8F5));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? darkNavyBgTop : lightBgTop,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: glassEnabled
            ? (isDark
                ? const Color(0xFF0B1822).withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.75))
            : (isDark ? const Color(0xFF0E1D28) : Colors.white),
        foregroundColor: isDark ? Colors.white : const Color(0xFF102018),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: glassEnabled
            ? (isDark
                ? const Color(0xFF0B1822).withValues(alpha: 0.80)
                : Colors.white.withValues(alpha: 0.82))
            : (isDark ? const Color(0xFF0E1D28) : Colors.white),
        indicatorColor: limeAccent.withValues(alpha: isDark ? 0.28 : 0.35),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: glassEnabled ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: glassEnabled
                ? Colors.white.withValues(alpha: isDark ? 0.18 : 0.65)
                : colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 1.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xFFBFD4C5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: limeAccent,
            width: 1.8,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 48),
          backgroundColor: isDark ? limeAccent : const Color(0xFF3E6B14),
          foregroundColor: isDark ? const Color(0xFF09160E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  static BoxDecoration gradientBackground({
    required Brightness brightness,
    required bool glassEnabled,
  }) {
    final isDark = brightness == Brightness.dark;
    if (!glassEnabled) {
      return BoxDecoration(
        color: isDark ? darkNavyBgTop : lightBgTop,
      );
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [
                darkNavyBgTop,
                Color(0xFF0E2229),
                darkGreenBgBottom,
              ]
            : const [
                lightBgTop,
                Color(0xFFE7F3E3),
                lightBgBottom,
              ],
      ),
    );
  }
}
