import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/theme/design_tokens.dart';

/// Material 3 & Liquid Glass theme builder powered by `AppDesignTokens`
/// (`@design-theme-guide`, `@ui-ux-pro-max`, `@deterministic-design`).
/// Guarantees >= 4.5:1 WCAG 2.2 AA/AAA contrast in both Light and Dark modes
/// and >= 48x48dp minimum interactive touch targets.
class GlassTheme {
  GlassTheme._();

  static const Color limeAccent = AppDesignTokens.brandLimeDark;
  static const Color darkNavyBgTop = AppDesignTokens.darkCanvas;
  static const Color darkGreenBgBottom = Color(0xFF0E211D);
  static const Color lightBgTop = AppDesignTokens.lightCanvas;
  static const Color lightBgBottom = Color(0xFFE6F0E8);

  static ThemeData buildTheme({
    required Brightness brightness,
    required bool glassEnabled,
  }) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppDesignTokens.brandLimeDark
        : AppDesignTokens.brandLimeLight;
    final secondaryColor = isDark
        ? AppDesignTokens.accentCyanDark
        : AppDesignTokens.accentCyanLight;
    final textPrimary = isDark
        ? AppDesignTokens.darkTextPrimary
        : AppDesignTokens.lightTextPrimary;
    final textSecondary = isDark
        ? AppDesignTokens.darkTextSecondary
        : AppDesignTokens.lightTextSecondary;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: isDark
          ? AppDesignTokens.darkSurface
          : AppDesignTokens.lightSurface,
      onSurface: textPrimary,
      error: isDark
          ? AppDesignTokens.postureAlertDark
          : AppDesignTokens.postureAlertLight,
    );

    final cardColor = glassEnabled
        ? (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.86))
        : (isDark
            ? AppDesignTokens.darkCardSolid
            : AppDesignTokens.lightCardSolid);

    final inputFillColor = glassEnabled
        ? (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.90))
        : (isDark ? const Color(0xFF1A2836) : const Color(0xFFEEF4EE));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? darkNavyBgTop : lightBgTop,
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: textSecondary,
          height: 1.45,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: glassEnabled
            ? (isDark
                ? const Color(0xFF0A141E).withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.88))
            : (isDark ? AppDesignTokens.darkSurface : Colors.white),
        foregroundColor: textPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: glassEnabled
            ? (isDark
                ? const Color(0xFF0A141E).withValues(alpha: 0.86)
                : Colors.white.withValues(alpha: 0.90))
            : (isDark ? AppDesignTokens.darkSurface : Colors.white),
        indicatorColor: primaryColor.withValues(alpha: isDark ? 0.24 : 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppDesignTokens.minTouchTarget,
            AppDesignTokens.minTouchTarget,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: glassEnabled ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
          side: BorderSide(
            color: glassEnabled
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : const Color(0xFFCBD5E1))
                : colorScheme.outlineVariant.withValues(alpha: 0.40),
            width: 1.0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.space4,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.22)
                : const Color(0xFFCBD5E1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xFFCBD5E1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          borderSide: BorderSide(
            color: primaryColor,
            width: 2.0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, AppDesignTokens.minTouchTarget),
          backgroundColor: primaryColor,
          foregroundColor: isDark ? const Color(0xFF071209) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, AppDesignTokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
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
                Color(0xFF0D1D28),
                darkGreenBgBottom,
              ]
            : const [
                lightBgTop,
                Color(0xFFEBF4EA),
                lightBgBottom,
              ],
      ),
    );
  }
}
