import 'package:flutter/material.dart';

import '../../core/design_system/foundations/star_kids_colors.dart';
import '../../core/design_system/foundations/sk_tokens.dart';

abstract final class StarKidsTextTheme {
  static const String displayFontFamily = 'Fraunces';
  static const String bodyFontFamily = 'Geist';
  static const String monoFontFamily = 'GeistMono';

  static TextTheme buildDark() {
    return build().apply(
      bodyColor: StarKidsDarkColors.textPrimary,
      displayColor: StarKidsDarkColors.textPrimary,
    );
  }

  static TextTheme build() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 34,
        fontWeight: FontWeight.w400,
        height: 1.05,
        letterSpacing: -0.85,
        color: SK.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 26,
        fontWeight: FontWeight.w400,
        height: 1.08,
        letterSpacing: -0.52,
        color: SK.ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w400,
        height: 1.1,
        letterSpacing: -0.44,
        color: SK.ink,
      ),
      displaySmall: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w400,
        height: 1.12,
        letterSpacing: -0.4,
        color: SK.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.17,
        color: SK.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.15,
        color: SK.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: SK.ink2,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: SK.ink2,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: SK.ink3,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: SK.ink,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.38,
        color: SK.ink3,
      ),
      labelSmall: TextStyle(
        fontFamily: monoFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.32,
        color: SK.ink3,
      ),
    );
  }
}
