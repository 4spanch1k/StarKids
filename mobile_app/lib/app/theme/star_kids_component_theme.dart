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
        minimumSize: const WidgetStatePropertyAll(
          Size(double.infinity, 56),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StarKidsRadii.full),
          ),
        ),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return StarKidsColors.actionDisabledBg;
          }

          if (states.contains(WidgetState.pressed)) {
            return StarKidsColors.brandPrimaryPressed;
          }

          return StarKidsColors.brandPrimary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return StarKidsColors.actionDisabledFg;
          }

          return StarKidsColors.textInverse;
        }),
        textStyle: WidgetStatePropertyAll(
          StarKidsTextTheme.build().labelLarge,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData outlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(double.infinity, 56),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StarKidsRadii.full),
          ),
        ),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return StarKidsColors.surfaceSecondary;
          }

          if (states.contains(WidgetState.pressed)) {
            return StarKidsColors.surfaceSecondary;
          }

          return StarKidsColors.glassSurface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return StarKidsColors.actionDisabledFg;
          }

          return StarKidsColors.textPrimary;
        }),
        side: const WidgetStatePropertyAll(
          BorderSide(
            color: StarKidsColors.borderDefault,
          ),
        ),
        textStyle: WidgetStatePropertyAll(
          StarKidsTextTheme.build().labelLarge,
        ),
      ),
    );
  }

  static InputDecorationTheme inputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: StarKidsColors.glassSurface,
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
      height: 68,
      backgroundColor: StarKidsColors.glassSurface,
      indicatorColor: StarKidsColors.cosmicBlush,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final base = StarKidsTextTheme.build().labelMedium!;
        if (states.contains(WidgetState.selected)) {
          return base.copyWith(color: StarKidsColors.brandPrimary);
        }

        return base.copyWith(color: StarKidsColors.textSecondary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(
            color: StarKidsColors.brandPrimary,
            size: 22,
          );
        }

        return const IconThemeData(
          color: StarKidsColors.textSecondary,
          size: 22,
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
      color: StarKidsColors.glassSurface,
      margin: EdgeInsets.zero,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        side: const BorderSide(color: StarKidsColors.glassStroke),
      ),
    );
  }

  static List<BoxShadow> floatingShadow() => StarKidsShadows.depth2;

  // ─── Dark variants ────────────────────────────────────────────────────────

  static FilledButtonThemeData filledButtonThemeDark() {
    return FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 56)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StarKidsRadii.full),
          ),
        ),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: WidgetStatePropertyAll(
          StarKidsDarkColors.accentPink.withValues(alpha: 0.4),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return StarKidsDarkColors.actionDisabledBg;
          }
          if (states.contains(WidgetState.pressed)) {
            return StarKidsDarkColors.accentPink.withValues(alpha: 0.85);
          }
          return StarKidsDarkColors.accentPink;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return StarKidsDarkColors.actionDisabledFg;
          }
          return Colors.white;
        }),
        textStyle: WidgetStatePropertyAll(
          StarKidsTextTheme.buildDark().labelLarge,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData outlinedButtonThemeDark() {
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 56)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StarKidsRadii.full),
          ),
        ),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return StarKidsDarkColors.actionDisabledBg;
          }
          return StarKidsDarkColors.glassSurface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return StarKidsDarkColors.actionDisabledFg;
          }
          return StarKidsDarkColors.textPrimary;
        }),
        side: WidgetStatePropertyAll(
          BorderSide(color: StarKidsDarkColors.borderDefault),
        ),
        textStyle: WidgetStatePropertyAll(
          StarKidsTextTheme.buildDark().labelLarge,
        ),
      ),
    );
  }

  static InputDecorationTheme inputDecorationThemeDark() {
    return InputDecorationTheme(
      filled: true,
      fillColor: StarKidsDarkColors.glassSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.lg,
        vertical: StarKidsSpacing.md,
      ),
      hintStyle: StarKidsTextTheme.buildDark().bodyLarge?.copyWith(
            color: StarKidsDarkColors.textSecondary,
          ),
      labelStyle: StarKidsTextTheme.buildDark().labelMedium?.copyWith(
            color: StarKidsDarkColors.textSecondary,
          ),
      helperStyle: StarKidsTextTheme.buildDark().labelMedium?.copyWith(
            color: StarKidsDarkColors.textSecondary,
          ),
      errorStyle: StarKidsTextTheme.buildDark().labelMedium?.copyWith(
            color: StarKidsDarkColors.statusError,
          ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        borderSide: BorderSide(color: StarKidsDarkColors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        borderSide: BorderSide(color: StarKidsDarkColors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        borderSide: BorderSide(color: StarKidsDarkColors.borderFocus, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        borderSide: BorderSide(color: StarKidsDarkColors.borderError, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        borderSide: BorderSide(color: StarKidsDarkColors.borderError, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
        borderSide: BorderSide(color: StarKidsDarkColors.borderDefault),
      ),
    );
  }

  static AppBarTheme appBarThemeDark() {
    return AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: StarKidsDarkColors.surfaceCanvas,
      foregroundColor: StarKidsDarkColors.textPrimary,
      titleTextStyle: StarKidsTextTheme.buildDark().titleLarge,
      iconTheme: IconThemeData(
        color: StarKidsDarkColors.textPrimary,
        size: 24,
      ),
    );
  }

  static NavigationBarThemeData navigationBarThemeDark() {
    return NavigationBarThemeData(
      height: 68,
      backgroundColor: StarKidsDarkColors.navBarBg,
      indicatorColor: StarKidsDarkColors.navIndicator,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final base = StarKidsTextTheme.buildDark().labelMedium!;
        if (states.contains(WidgetState.selected)) {
          return base.copyWith(color: StarKidsDarkColors.accentPink);
        }
        return base.copyWith(color: StarKidsDarkColors.textSecondary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: StarKidsDarkColors.accentPink, size: 22);
        }
        return IconThemeData(color: StarKidsDarkColors.textSecondary, size: 22);
      }),
    );
  }

  static SnackBarThemeData snackBarThemeDark() {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: StarKidsDarkColors.surfaceElevated,
      contentTextStyle: StarKidsTextTheme.buildDark().bodyLarge?.copyWith(
            color: StarKidsDarkColors.textPrimary,
          ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.md),
      ),
    );
  }

  static CardThemeData cardThemeDark() {
    return CardThemeData(
      color: StarKidsDarkColors.glassSurface,
      margin: EdgeInsets.zero,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        side: BorderSide(color: StarKidsDarkColors.glassStroke, width: 0.5),
      ),
    );
  }
}
