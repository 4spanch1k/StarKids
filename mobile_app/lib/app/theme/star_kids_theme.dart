import 'package:flutter/material.dart';

import '../../core/design_system/foundations/star_kids_colors.dart';
import 'star_kids_component_theme.dart';
import 'star_kids_text_theme.dart';

abstract final class StarKidsTheme {
  static ThemeData light() {
    final textTheme = StarKidsTextTheme.build();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: StarKidsTextTheme.bodyFontFamily,
      scaffoldBackgroundColor: StarKidsColors.surfaceCanvas,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: StarKidsColors.brandPrimary,
        onPrimary: StarKidsColors.textInverse,
        secondary: StarKidsColors.brandSecondary,
        onSecondary: StarKidsColors.textInverse,
        error: StarKidsColors.statusError,
        onError: StarKidsColors.textInverse,
        background: StarKidsColors.surfaceCanvas,
        onBackground: StarKidsColors.textPrimary,
        surface: StarKidsColors.surfacePrimary,
        onSurface: StarKidsColors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: StarKidsComponentTheme.appBarTheme(),
      filledButtonTheme: StarKidsComponentTheme.filledButtonTheme(),
      outlinedButtonTheme: StarKidsComponentTheme.outlinedButtonTheme(),
      inputDecorationTheme: StarKidsComponentTheme.inputDecorationTheme(),
      navigationBarTheme: StarKidsComponentTheme.navigationBarTheme(),
      snackBarTheme: StarKidsComponentTheme.snackBarTheme(),
      cardTheme: StarKidsComponentTheme.cardTheme(),
      dividerColor: StarKidsColors.borderDefault,
      disabledColor: StarKidsColors.actionDisabledFg,
      splashColor: StarKidsColors.surfaceTertiary,
      highlightColor: Colors.transparent,
    );
  }
}

