import 'package:flutter/material.dart';

import '../../core/design_system/foundations/star_kids_colors.dart';
import '../../core/design_system/foundations/star_kids_radii.dart';
import '../../core/design_system/foundations/star_kids_shadows.dart';
import '../../core/design_system/foundations/star_kids_spacing.dart';
import 'star_kids_text_theme.dart';

abstract final class StarKidsComponentTheme {
  static FilledButtonThemeData filledButtonTheme() {
    return FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const MaterialStatePropertyAll(
          Size(double.infinity, 56),
        ),
        padding: const MaterialStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        ),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StarKidsRadii.full),
          ),
        ),
        elevation: const MaterialStatePropertyAll(0),
        shadowColor: const MaterialStatePropertyAll(Colors.transparent),
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return StarKidsColors.actionDisabledBg;
          }

          if (states.contains(MaterialState.pressed)) {
            return StarKidsColors.brandPrimaryPressed;
          }

          return StarKidsColors.brandPrimary;
        }),
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return StarKidsColors.actionDisabledFg;
          }

          return StarKidsColors.textInverse;
        }),
        textStyle: MaterialStatePropertyAll(
          StarKidsTextTheme.build().labelLarge,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData outlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const MaterialStatePropertyAll(
          Size(double.infinity, 56),
        ),
        padding: const MaterialStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        ),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StarKidsRadii.full),
          ),
        ),
        elevation: const MaterialStatePropertyAll(0),
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return StarKidsColors.surfaceSecondary;
          }

          if (states.contains(MaterialState.pressed)) {
            return StarKidsColors.surfaceSecondary;
          }

          return StarKidsColors.surfacePrimary;
        }),
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return StarKidsColors.actionDisabledFg;
          }

          return StarKidsColors.textPrimary;
        }),
        side: MaterialStatePropertyAll(
          BorderSide(
            color: StarKidsColors.borderDefault,
          ),
        ),
        textStyle: MaterialStatePropertyAll(
          StarKidsTextTheme.build().labelLarge,
        ),
      ),
    );
  }

  static InputDecorationTheme inputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: StarKidsColors.surfacePrimary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.lg,
        vertical: StarKidsSpacing.md,
      ),
      hintStyle: StarKidsTextTheme.build().bodyLarge?.copyWith(
            color: StarKidsColors.textSecondary,
          ),
      labelStyle: StarKidsTextTheme.build().labelMedium,
      helperStyle: StarKidsTextTheme.build().labelMedium,
      errorStyle: StarKidsTextTheme.build().labelMedium?.copyWith(
            color: StarKidsColors.statusError,
          ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        borderSide: const BorderSide(color: StarKidsColors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        borderSide: const BorderSide(color: StarKidsColors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        borderSide: const BorderSide(
          color: StarKidsColors.borderFocus,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        borderSide: const BorderSide(
          color: StarKidsColors.borderError,
          width: 2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        borderSide: const BorderSide(
          color: StarKidsColors.borderError,
          width: 2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        borderSide: const BorderSide(color: StarKidsColors.borderDefault),
      ),
    );
  }

  static AppBarTheme appBarTheme() {
    return AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: StarKidsColors.surfaceCanvas,
      foregroundColor: StarKidsColors.textPrimary,
      titleTextStyle: StarKidsTextTheme.build().titleLarge,
      iconTheme: const IconThemeData(
        color: StarKidsColors.textPrimary,
        size: 24,
      ),
    );
  }

  static NavigationBarThemeData navigationBarTheme() {
    return NavigationBarThemeData(
      height: 72,
      backgroundColor: StarKidsColors.surfacePrimary,
      indicatorColor: StarKidsColors.surfaceTertiary,
      elevation: 0,
      shadowColor: Colors.transparent,
      labelTextStyle: MaterialStateProperty.resolveWith((states) {
        final base = StarKidsTextTheme.build().labelMedium!;
        if (states.contains(MaterialState.selected)) {
          return base.copyWith(color: StarKidsColors.brandPrimary);
        }

        return base.copyWith(color: StarKidsColors.textSecondary);
      }),
      iconTheme: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return const IconThemeData(
            color: StarKidsColors.brandPrimary,
            size: 24,
          );
        }

        return const IconThemeData(
          color: StarKidsColors.textSecondary,
          size: 24,
        );
      }),
    );
  }

  static SnackBarThemeData snackBarTheme() {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: StarKidsColors.surfaceInverse,
      contentTextStyle: StarKidsTextTheme.build().bodyLarge?.copyWith(
            color: StarKidsColors.textInverse,
          ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
      ),
    );
  }

  static CardThemeData cardTheme() {
    return CardThemeData(
      color: StarKidsColors.surfacePrimary,
      margin: EdgeInsets.zero,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        side: const BorderSide(color: StarKidsColors.borderDefault),
      ),
    );
  }

  static List<BoxShadow> floatingShadow() => StarKidsShadows.depth2;
}
