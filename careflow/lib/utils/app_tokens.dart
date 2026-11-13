import 'package:flutter/material.dart';

/// 8-point spacing scale. Only these values are allowed in UI code.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Standard screen gutter and card padding.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg, vertical: lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets cardCompact = EdgeInsets.all(md);
  static const EdgeInsets pageVertical = EdgeInsets.symmetric(vertical: lg);
}

/// Three radii only: small controls, surfaces/inputs, sheets/dialogs.
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;

  static BorderRadius get small => BorderRadius.circular(sm);
  static BorderRadius get medium => BorderRadius.circular(md);
  static BorderRadius get large => BorderRadius.circular(lg);
  static BorderRadius get sheet => const BorderRadius.vertical(top: Radius.circular(lg));
}

/// Two elevation presets, tinted rather than pure black.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0F0B1220),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x1A0B1220),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

/// Six text roles, three weights (400 / 600 / 700).
class AppTypography {
  AppTypography._();

  static const TextStyle display = TextStyle(
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle section = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.15,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );
}

/// One icon size family, used everywhere.
class AppIconSize {
  AppIconSize._();

  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double hero = 40;
}

/// Shared control metrics so hit targets never fall below 48 dp.
class AppMetrics {
  AppMetrics._();

  static const double controlHeight = 48;
  static const double minTarget = 48;
  static const double navIcon = 22;
}
