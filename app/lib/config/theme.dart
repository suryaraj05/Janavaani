import 'package:flutter/material.dart';
import 'app_design_system.dart';

/// Theme configuration using the modern design system
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppDesignSystem.primaryColor,
        primary: AppDesignSystem.primaryColor,
        secondary: AppDesignSystem.secondaryColor,
        background: AppDesignSystem.backgroundColor,
        surface: AppDesignSystem.surfaceColor,
        error: AppDesignSystem.errorColor,
        brightness: Brightness.light,
      ),
      textTheme: TextTheme(
        displayLarge: AppDesignSystem.heading1,
        displayMedium: AppDesignSystem.heading2,
        displaySmall: AppDesignSystem.heading3,
        headlineMedium: AppDesignSystem.heading4,
        bodyLarge: AppDesignSystem.bodyLarge,
        bodyMedium: AppDesignSystem.bodyMedium,
        bodySmall: AppDesignSystem.bodySmall,
        labelLarge: AppDesignSystem.labelLarge,
        labelMedium: AppDesignSystem.labelMedium,
        labelSmall: AppDesignSystem.labelSmall,
      ),
      scaffoldBackgroundColor: AppDesignSystem.backgroundColor,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppDesignSystem.surfaceColor,
        foregroundColor: AppDesignSystem.textPrimary,
        titleTextStyle: AppDesignSystem.heading4,
        iconTheme: const IconThemeData(
          color: AppDesignSystem.textPrimary,
          size: 24,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        ),
        color: AppDesignSystem.cardColor,
        margin: const EdgeInsets.all(AppDesignSystem.spacingM),
      ),
      inputDecorationTheme: AppDesignSystem.inputDecorationTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppDesignSystem.primaryButtonStyle,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppDesignSystem.secondaryButtonStyle,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppDesignSystem.primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.spacingM,
            vertical: AppDesignSystem.spacingS,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppDesignSystem.primaryColor.withOpacity(0.1),
        labelStyle: AppDesignSystem.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM,
          vertical: AppDesignSystem.spacingS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppDesignSystem.dividerColor,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppDesignSystem.primaryColor,
        primary: AppDesignSystem.primaryLight,
        secondary: AppDesignSystem.secondaryColor,
        brightness: Brightness.dark,
      ),
      textTheme: TextTheme(
        displayLarge: AppDesignSystem.heading1.copyWith(color: Colors.white),
        displayMedium: AppDesignSystem.heading2.copyWith(color: Colors.white),
        displaySmall: AppDesignSystem.heading3.copyWith(color: Colors.white),
        headlineMedium: AppDesignSystem.heading4.copyWith(color: Colors.white),
        bodyLarge: AppDesignSystem.bodyLarge.copyWith(color: Colors.white),
        bodyMedium: AppDesignSystem.bodyMedium.copyWith(color: Colors.white70),
        bodySmall: AppDesignSystem.bodySmall.copyWith(color: Colors.white60),
        labelLarge: AppDesignSystem.labelLarge.copyWith(color: Colors.white),
        labelMedium: AppDesignSystem.labelMedium.copyWith(color: Colors.white),
        labelSmall: AppDesignSystem.labelSmall.copyWith(color: Colors.white70),
      ),
      scaffoldBackgroundColor: const Color(0xFF111827),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        titleTextStyle: AppDesignSystem.heading4.copyWith(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        ),
        color: const Color(0xFF1F2937),
      ),
    );
  }
}

