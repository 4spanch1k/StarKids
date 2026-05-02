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
      scaffoldBackgroundColor: StarKidsColors.cosmicBg,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: StarKidsColors.brandPrimary,
        onPrimary: StarKidsColors.textInverse,
        secondary: StarKidsColors.brandSecondary,
        onSecondary: StarKidsColors.textInverse,
        error: StarKidsColors.statusError,
        onError: StarKidsColors.textInverse,
        surface: StarKidsColors.cosmicBg,
        onSurface: StarKidsColors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: StarKidsComponentTheme.appBarTheme(),
      filledButtonTheme: StarKidsComponentTheme.filledButtonTheme(),
      outlinedButtonTheme: StarKidsComponentTheme.outlinedButtonTheme(),
      textButtonTheme: StarKidsComponentTheme.textButtonTheme(),
      inputDecorationTheme: StarKidsComponentTheme.inputDecorationTheme(),
      navigationBarTheme: StarKidsComponentTheme.navigationBarTheme(),
      snackBarTheme: StarKidsComponentTheme.snackBarTheme(),
      cardTheme: StarKidsComponentTheme.cardTheme(),
      bottomSheetTheme: StarKidsComponentTheme.bottomSheetTheme(),
      dialogTheme: StarKidsComponentTheme.dialogTheme(),
      popupMenuTheme: StarKidsComponentTheme.popupMenuTheme(),
      datePickerTheme: StarKidsComponentTheme.datePickerTheme(),
      dividerColor: StarKidsColors.borderDefault,
      disabledColor: StarKidsColors.actionDisabledFg,
      splashColor: StarKidsColors.cosmicBlush,
      highlightColor: Colors.transparent,
    );
  }

  static ThemeData dark() {
    final textTheme = StarKidsTextTheme.buildDark();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: StarKidsTextTheme.bodyFontFamily,
      scaffoldBackgroundColor: StarKidsDarkColors.bg,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: StarKidsDarkColors.brandPrimary,
        onPrimary: Colors.white,
        secondary: StarKidsColors.brandSecondary,
        onSecondary: Colors.white,
        error: StarKidsDarkColors.statusError,
        onError: Colors.white,
        surface: StarKidsDarkColors.surfacePrimary,
        onSurface: StarKidsDarkColors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: StarKidsComponentTheme.appBarThemeDark(),
      filledButtonTheme: StarKidsComponentTheme.filledButtonThemeDark(),
      outlinedButtonTheme: StarKidsComponentTheme.outlinedButtonThemeDark(),
      textButtonTheme: StarKidsComponentTheme.textButtonThemeDark(),
      inputDecorationTheme: StarKidsComponentTheme.inputDecorationThemeDark(),
      navigationBarTheme: StarKidsComponentTheme.navigationBarThemeDark(),
      snackBarTheme: StarKidsComponentTheme.snackBarThemeDark(),
      cardTheme: StarKidsComponentTheme.cardThemeDark(),
      bottomSheetTheme: StarKidsComponentTheme.bottomSheetThemeDark(),
      dialogTheme: StarKidsComponentTheme.dialogThemeDark(),
      popupMenuTheme: StarKidsComponentTheme.popupMenuThemeDark(),
      datePickerTheme: StarKidsComponentTheme.datePickerThemeDark(),
      dividerColor: StarKidsDarkColors.borderDefault,
      disabledColor: StarKidsDarkColors.actionDisabledFg,
      splashColor: StarKidsDarkColors.nebulaViolet,
      highlightColor: Colors.transparent,
    );
  }
}
