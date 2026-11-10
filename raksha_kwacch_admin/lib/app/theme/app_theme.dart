import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandRed,
        surface: AppColors.surface,
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1,
        color: AppColors.border,
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textDark),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.textSlate),
      ),
    );
  }
}
