import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentOrange = Color(0xFFFF9800);
  
  // Neutral Colors (Slate Palette)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);

  // Spacing & Radius (8pt Grid)
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;

  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        onPrimary: Colors.white,
        secondary: accentBlue,
        onSecondary: Colors.white,
        tertiary: accentOrange,
        background: lightBg,
        surface: lightSurface,
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
        displayMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: primaryBlue.withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryBlue);
          }
          return const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.grey);
        }),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 1, // Soft elevation
        shadowColor: Colors.black.withOpacity(0.05),
        color: lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusL)),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: accentBlue, // Lighter blue for dark theme visibility
        onPrimary: Colors.white,
        secondary: primaryBlue,
        onSecondary: Colors.white,
        tertiary: accentOrange,
        background: darkBg,
        surface: darkSurface,
        brightness: Brightness.dark,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentBlue),
        displayMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white70),
        labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white60),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: accentBlue.withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: accentBlue);
          }
          return const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.white60);
        }),
      ),
      scaffoldBackgroundColor: darkBg,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black45,
        color: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusL)),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF2A374A), // Dark default
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.all(spacingM),
      ),
    );
  }
}
