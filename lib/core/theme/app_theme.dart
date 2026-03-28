import 'package:flutter/material.dart';

class AppColors {
  // Palette principale
  static const Color navyBlue = Color(0xFF1A3A5C);
  static const Color activeBlue = Color(0xFF2E75B6);
  static const Color energyOrange = Color(0xFFE87722);

  // Palette secondaire
  static const Color successGreen = Color(0xFF1A7A4A);
  static const Color alertRed = Color(0xFFC0392B);
  static const Color neutralGray = Color(0xFF6B7280);

  // Neutres
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF0A0A0A);
  static const Color surfaceLight = Color(0xFFF8F9FA);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color cardDark = Color(0xFF16213E);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.navyBlue,
        secondary: AppColors.energyOrange,
        tertiary: AppColors.activeBlue,
        surface: AppColors.surfaceLight,
        error: AppColors.alertRed,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.black,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 32,
          color: AppColors.navyBlue,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: AppColors.navyBlue,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: AppColors.navyBlue,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: AppColors.navyBlue,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w400,
          fontSize: 16,
          color: AppColors.black,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: AppColors.neutralGray,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.white,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navyBlue,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.white,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.energyOrange,
        unselectedItemColor: AppColors.neutralGray,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.energyOrange,
        foregroundColor: AppColors.white,
        elevation: 6,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 4,
        shadowColor: AppColors.navyBlue.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.energyOrange,
          foregroundColor: AppColors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neutralGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.activeBlue, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.neutralGray),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.activeBlue,
        secondary: AppColors.energyOrange,
        tertiary: AppColors.navyBlue,
        surface: AppColors.surfaceDark,
        error: AppColors.alertRed,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.white,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 32,
          color: AppColors.white,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: AppColors.white,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: AppColors.white,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: AppColors.white,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w400,
          fontSize: 16,
          color: AppColors.white,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: AppColors.neutralGray,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.white,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.white,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardDark,
        selectedItemColor: AppColors.energyOrange,
        unselectedItemColor: AppColors.neutralGray,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.energyOrange,
        foregroundColor: AppColors.white,
        elevation: 6,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.energyOrange,
          foregroundColor: AppColors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}