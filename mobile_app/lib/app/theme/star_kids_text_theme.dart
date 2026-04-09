import 'package:flutter/material.dart';

import '../../core/design_system/foundations/star_kids_colors.dart';

abstract final class StarKidsTextTheme {
  static const String displayFontFamily = 'Sora';
  static const String bodyFontFamily = 'Manrope';

  static TextTheme build() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 40 / 36,
        color: StarKidsColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 34 / 28,
        color: StarKidsColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 30 / 24,
        color: StarKidsColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 26 / 20,
        color: StarKidsColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
        color: StarKidsColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 22 / 14,
        color: StarKidsColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 20 / 16,
        color: StarKidsColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 18 / 13,
        color: StarKidsColors.textSecondary,
      ),
    );
  }
}
