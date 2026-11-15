import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography definitions based on Google Stitch Design Specification
/// Reference: stitch_raksha_kawach_app_redesign/raksha_kawach/DESIGN.md
abstract final class AppTypography {
  static const List<String> headingFontFallbacks = [
    'Plus Jakarta Sans',
    'system-ui',
    '-apple-system',
    'Roboto',
    'sans-serif',
  ];

  static const List<String> bodyFontFallbacks = [
    'Inter',
    'system-ui',
    '-apple-system',
    'Roboto',
    'sans-serif',
  ];

  static const List<String> monoFontFallbacks = [
    'Roboto Mono',
    'SF Mono',
    'Menlo',
    'monospace',
  ];

  // Display: Plus Jakarta Sans 34px, 700, 40px line-height, -0.03em tracking
  static const TextStyle display = TextStyle(
    fontFamilyFallback: headingFontFallbacks,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 40 / 34,
    letterSpacing: -1.02, // -0.03em * 34
    color: AppColors.onSurface,
  );

  // Headline Large: Plus Jakarta Sans 26px, 600, 32px line-height, -0.02em tracking
  static const TextStyle headlineLg = TextStyle(
    fontFamilyFallback: headingFontFallbacks,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 32 / 26,
    letterSpacing: -0.52, // -0.02em * 26
    color: AppColors.onSurface,
  );

  // Headline Medium: Plus Jakarta Sans 20px, 600, 26px line-height, -0.015em tracking
  static const TextStyle headlineMd = TextStyle(
    fontFamilyFallback: headingFontFallbacks,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 26 / 20,
    letterSpacing: -0.3, // -0.015em * 20
    color: AppColors.onSurface,
  );

  // Headline Small: Plus Jakarta Sans 17px, 600, 22px line-height, -0.01em tracking
  static const TextStyle headlineSm = TextStyle(
    fontFamilyFallback: headingFontFallbacks,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 22 / 17,
    letterSpacing: -0.17, // -0.01em * 17
    color: AppColors.onSurface,
  );

  // Body Large: Inter 16px, 400, 24px line-height, -0.01em tracking
  static const TextStyle bodyLg = TextStyle(
    fontFamilyFallback: bodyFontFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    letterSpacing: -0.16, // -0.01em * 16
    color: AppColors.onSurface,
  );

  // Body Medium: Inter 14px, 400, 20px line-height, 0em tracking
  static const TextStyle bodyMd = TextStyle(
    fontFamilyFallback: bodyFontFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    letterSpacing: 0,
    color: AppColors.onSurface,
  );

  // Body Small: Inter 12px, 400, 16px line-height, 0.01em tracking
  static const TextStyle bodySm = TextStyle(
    fontFamilyFallback: bodyFontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    letterSpacing: 0.12, // 0.01em * 12
    color: AppColors.onSurfaceVariant,
  );

  // Label Large: Inter 14px, 600, 18px line-height, 0.01em tracking
  static const TextStyle labelLg = TextStyle(
    fontFamilyFallback: bodyFontFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 18 / 14,
    letterSpacing: 0.14, // 0.01em * 14
    color: AppColors.onSurface,
  );

  // Label Medium: Inter 12px, 500, 16px line-height, 0.02em tracking
  static const TextStyle labelMd = TextStyle(
    fontFamilyFallback: bodyFontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.24, // 0.02em * 12
    color: AppColors.onSurfaceVariant,
  );

  // Label Small: Inter 10px, 600, 12px line-height, 0.04em tracking
  static const TextStyle labelSm = TextStyle(
    fontFamilyFallback: bodyFontFallbacks,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 12 / 10,
    letterSpacing: 0.4, // 0.04em * 10
    color: AppColors.onSurfaceVariant,
  );

  // Monospace with Tabular Figures (used for vehicle plates, student IDs, RFID, telemetry)
  static const TextStyle tabularMono = TextStyle(
    fontFamilyFallback: monoFontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: 0.5,
    color: AppColors.onSurface,
  );

  /// Material 3 TextTheme representation of Stitch Typography
  static TextTheme get textTheme => const TextTheme(
        displayLarge: display,
        headlineLarge: headlineLg,
        headlineMedium: headlineMd,
        headlineSmall: headlineSm,
        bodyLarge: bodyLg,
        bodyMedium: bodyMd,
        bodySmall: bodySm,
        labelLarge: labelLg,
        labelMedium: labelMd,
        labelSmall: labelSm,
      );
}
