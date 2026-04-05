import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light() {
    const accentColor = Color(0xFFF97316);
    const surfaceColor = Color(0xFFFFFBF6);
    const textColor = Color(0xFF1F2937);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: surfaceColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.light,
        surface: surfaceColor,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: surfaceColor,
        foregroundColor: textColor,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFE4C7)),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.45,
          color: textColor,
        ),
      ),
    );
  }
}

