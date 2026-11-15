import 'package:flutter/material.dart';

/// Exact color palette tokens from Google Stitch Design System
/// Reference: stitch_raksha_kawach_app_redesign/raksha_kawach/DESIGN.md
abstract final class AppColors {
  // Brand & Primary
  static const Color primary = Color(0xFF386A0B);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF83BC57);
  static const Color onPrimaryContainer = Color(0xFF224A00);
  static const Color inversePrimary = Color(0xFF9CD76E);

  // Surfaces & Background
  static const Color surface = Color(0xFFF9FAF7);
  static const Color surfaceDim = Color(0xFFD9DAD7);
  static const Color surfaceBright = Color(0xFFF9FAF7);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF); // White Card Plane
  static const Color surfaceContainerLow = Color(0xFFF3F4F1);
  static const Color surfaceContainer = Color(0xFFEDEEEB);
  static const Color surfaceContainerHigh = Color(0xFFE7E8E6);
  static const Color surfaceContainerHighest = Color(0xFFE2E3E0);

  // Text & Neutrals
  static const Color onSurface = Color(0xFF191C1B); // Dark Charcoal
  static const Color onSurfaceVariant = Color(0xFF42493B);
  static const Color deepCharcoal = Color(0xFF171717);

  // Inverse Surfaces (used for high-contrast attendance cards)
  static const Color inverseSurface = Color(0xFF2E312F);
  static const Color inverseOnSurface = Color(0xFFF0F1EE);

  // Outlines & Borders
  static const Color outline = Color(0xFF727A69);
  static const Color outlineVariant = Color(0xFFE8EBE6); // Hairline border
  static const Color borderSubtle = Color(0xFFC2C9B6);

  // Secondary
  static const Color secondary = Color(0xFF5F5E5E);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE2DFDE);
  static const Color onSecondaryContainer = Color(0xFF636262);

  // Tertiary
  static const Color tertiary = Color(0xFF036D38);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF67BF80);
  static const Color onTertiaryContainer = Color(0xFF004B24);

  // Semantic Feedback
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color warning = Color(0xFFE6A34B);
  static const Color warningContainer = Color(0xFFFFE0B2);
  static const Color onWarningContainer = Color(0xFF5D3F00);

  static const Color success = Color(0xFF386A0B);
  static const Color successContainer = Color(0xFF83BC57);
  static const Color onSuccessContainer = Color(0xFF224A00);

  // Fixed Tonal Tokens
  static const Color primaryFixed = Color(0xFFB7F487);
  static const Color primaryFixedDim = Color(0xFF9CD76E);
  static const Color onPrimaryFixed = Color(0xFF0B2000);
  static const Color onPrimaryFixedVariant = Color(0xFF265100);

  static const Color tertiaryFixed = Color(0xFF9CF6B3);
  static const Color tertiaryFixedDim = Color(0xFF80D998);
  static const Color onTertiaryFixed = Color(0xFF00210D);
  static const Color onTertiaryFixedVariant = Color(0xFF005228);

  // Legacy compatibility aliases for un-migrated components
  static const Color legacyCoral = Color(0xFFF87171);
  static const Color legacyNavy = Color(0xFF0A0E1A);
  static const Color legacyNavyCard = Color(0xFF161B2E);
}

