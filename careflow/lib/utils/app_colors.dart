import 'package:flutter/material.dart';

/// CareFlow design tokens.
///
/// One brand accent (the blue from the supplied heart/flow logo), tinted
/// blue-grey neutrals, and semantic colours only where meaning requires it.
class AppColors {
  AppColors._();

  // --- Brand core (derived from assets/branding/careflow-logo.svg) ---
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFFE8F0FE); // soft container
  static const Color primaryContainerDark = Color(0xFF1B2C52);
  static const Color primaryStrong = Color(0xFF3B82F6); // logo highlight

  // Backwards-compatible aliases. The teal/mint second accent is retired so
  // every screen now speaks the same single brand language.
  static const Color healthcareTeal = primary;
  static const Color healthcareTealLight = primaryLight;
  static const Color healthcareTealDark = primaryDark;
  static const Color lightMint = primaryLight;
  static const Color mintAccent = success;
  static const Color mintDark = successText;

  // --- Light surfaces & text (tinted, never pure black/white) ---
  static const Color backgroundLight = Color(0xFFF5F7FB);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardTintLight = Color(0xFFEDF1F7);
  static const Color surfaceSunken = Color(0xFFF0F4FA);
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF5B6575);
  static const Color textTertiaryLight = Color(0xFF667085);
  static const Color borderLight = Color(0xFFDDE3ED);
  static const Color dividerLight = Color(0xFFEBEFF6);

  // --- Dark surfaces & text ---
  static const Color backgroundDark = Color(0xFF0C1220);
  static const Color cardDark = Color(0xFF141C2B);
  static const Color cardTintDark = Color(0xFF1B2536);
  static const Color textPrimaryDark = Color(0xFFF2F5FA);
  static const Color textSecondaryDark = Color(0xFFA7B0C0);
  static const Color textTertiaryDark = Color(0xFF7D8798);
  static const Color borderDark = Color(0xFF263246);
  static const Color dividerDark = Color(0xFF1B2536);

  // --- Semantic feedback ---
  static const Color success = Color(0xFF0E9F6E);
  static const Color successText = Color(0xFF047857);
  static const Color successLight = Color(0xFFE6F7F0);
  static const Color successSoftDark = Color(0xFF0D2E25);

  static const Color destructive = Color(0xFFD92D20);
  static const Color destructiveText = Color(0xFFB42318);
  static const Color destructiveLight = Color(0xFFFEE4E2);
  static const Color destructiveSoftDark = Color(0xFF3B1715);

  static const Color warning = Color(0xFFB45309);
  static const Color warningText = Color(0xFF92400E);
  static const Color warningLight = Color(0xFFFEF3E2);
  static const Color warningSoftDark = Color(0xFF38260B);

  static const Color info = primary;
  static const Color infoLight = primaryLight;

  static const Color starAmber = Color(0xFFD99E0B);
  static const Color starLight = Color(0xFFFEF6E0);
  static const Color starSoftDark = Color(0xFF3A2B09);

  // --- Helpers ---
  static Color background(bool isDark) =>
      isDark ? backgroundDark : backgroundLight;
  static Color card(bool isDark) => isDark ? cardDark : cardLight;
  static Color textPrimary(bool isDark) =>
      isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) =>
      isDark ? textSecondaryDark : textSecondaryLight;
  static Color border(bool isDark) => isDark ? borderDark : borderLight;
}
