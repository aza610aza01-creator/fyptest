import 'package:flutter/material.dart';

/// Centralized Design Token Register for AI Gym Cloud v5.0 (`@design-theme-guide`,
/// `@ui-ux-pro-max`, `@ui-motion`, `@deterministic-design`).
/// Every color pair has been verified against WCAG 2.2 AA/AAA in both Light and Dark modes.
class AppDesignTokens {
  AppDesignTokens._();

  // ---------------------------------------------------------------------------
  // 1. Color Tokens (Dark & Light Mode WCAG 2.2 Verified)
  // ---------------------------------------------------------------------------
  static const Color darkCanvas = Color(0xFF070B10);
  static const Color darkSurface = Color(0xFF101822);
  static const Color darkCardSolid = Color(0xFF141E2B);
  static const Color darkTextPrimary = Color(0xFFF5F7FA);   // 18.4:1 vs darkCanvas (AAA)
  static const Color darkTextSecondary = Color(0xFF9EB0C2); // 8.6:1 vs darkCanvas (AAA)

  static const Color lightCanvas = Color(0xFFF4F7F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardSolid = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);   // 16.5:1 vs lightCanvas (AAA)
  static const Color lightTextSecondary = Color(0xFF334155); // 9.4:1 vs lightCanvas (AAA)

  static const Color brandLimeDark = Color(0xFF9ED756);      // 11.2:1 vs darkCanvas (AAA)
  static const Color brandLimeLight = Color(0xFF2E5A12);     // 7.4:1 vs lightCanvas (AAA)
  static const Color accentCyanDark = Color(0xFF5CE1E6);     // 11.8:1 vs darkCanvas (AAA)
  static const Color accentCyanLight = Color(0xFF0B5E7A);    // 6.8:1 vs lightCanvas (AA)

  static const Color postureCorrectDark = Color(0xFF30D158);
  static const Color postureCorrectLight = Color(0xFF156D2F);
  static const Color postureAdjustDark = Color(0xFFFF9F0A);
  static const Color postureAdjustLight = Color(0xFF8A4B00);
  static const Color postureAlertDark = Color(0xFFFF453A);
  static const Color postureAlertLight = Color(0xFFB42318);

  // ---------------------------------------------------------------------------
  // 2. Deterministic 8pt Spatial Grid & Radius Tokens (`@deterministic-design`)
  // ---------------------------------------------------------------------------
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space8 = 32.0;

  static const double radiusSm = 10.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 22.0;
  static const double radiusXl = 28.0;
  static const double radiusPill = 999.0;

  static const double minTouchTarget = 48.0;

  // ---------------------------------------------------------------------------
  // 3. StyleSeed Motion Tokens (`@ui-motion` — Silk & Spring seeds)
  //    Honors `reducedMotionEnabled` by collapsing duration to Duration.zero.
  // ---------------------------------------------------------------------------
  static Duration silkEntranceDuration({bool reducedMotion = false}) =>
      reducedMotion ? Duration.zero : const Duration(milliseconds: 220);

  static Duration springPressDuration({bool reducedMotion = false}) =>
      reducedMotion ? Duration.zero : const Duration(milliseconds: 140);

  static Curve get silkCurve => Curves.easeOutCubic;
  static Curve get springCurve => Curves.easeOutBack;
  // ---------------------------------------------------------------------------
  // 4. v6.2 Six UI/UX Design Paradigm Tokens (Flat, Glass, Neomorphism,
  //    Skeuomorphism, High-Contrast Dark Mode, Bento Box Grid)
  // ---------------------------------------------------------------------------
  static const Color flatPrimaryIndigo = Color(0xFF2563EB);
  static const Color flatBorderSolid = Color(0xFF0F172A);
  static const Color neomorphicLightSurface = Color(0xFFE0E5EC);
  static const Color neomorphicShadowDark = Color(0xFFB8C1CE);
  static const Color neomorphicShadowLight = Color(0xFFFFFFFF);
  static const Color skeuoLeatherDark = Color(0xFF4A2E1B);
  static const Color skeuoLeatherLight = Color(0xFF6E472B);
  static const Color skeuoStitchGold = Color(0xFFD4AF37);
  static const Color skeuoParchment = Color(0xFFFDF8EE);
  static const Color oledHighContrastDark = Color(0xFF030509);
  static const Color bentoSurfaceDark = Color(0xFF121726);
}
