// lib/core/design_system/sk_theme.dart
//
// SKTheme — InheritedWidget that exposes SKColorScheme to the widget tree.
// Already wired in app.dart via MaterialApp.builder (Step 2).
//
// buildMaterialTheme() is now the canonical AppTheme (wired in Step 4).
// It replaces StarKidsTheme entirely — all component themes use c.* tokens.
//
// Usage in widgets:
//   final c = SKTheme.of(context).colors;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'sk_color_scheme.dart';
import 'sk_design_tokens.dart';

class SKTheme extends InheritedWidget {
  final SKColorScheme colors;
  final bool dark;

  const SKTheme({
    super.key,
    required this.colors,
    required this.dark,
    required super.child,
  });

  static SKTheme of(BuildContext context) {
    final t = context.dependOnInheritedWidgetOfExactType<SKTheme>();
    assert(
      t != null,
      'SKTheme not found in the widget tree. '
      'Make sure MaterialApp.builder wraps its child in SKTheme.',
    );
    return t!;
  }

  @override
  bool updateShouldNotify(SKTheme old) => old.dark != dark;

  // ── Material ThemeData ─────────────────────────────────────────────────────
  //
  // Single source of truth for the whole app after Step 4.
  // Fonts: Plus Jakarta Sans (body/buttons/labels) + Bricolage Grotesque (display/headline).
  // Colors: all resolved from SKColorScheme so light/dark work automatically.

  static ThemeData buildMaterialTheme({required bool dark}) {
    final c = dark ? SKColorScheme.dark() : SKColorScheme.light();

    // Plus Jakarta Sans as the base text theme; Bricolage Grotesque overrides
    // the display/headline slots below.
    final base = GoogleFonts.plusJakartaSansTextTheme(
      dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    final tt = base.copyWith(
      displayLarge:   SKTextStyles.d1.copyWith(color: c.textPrimary),
      displayMedium:  SKTextStyles.d2.copyWith(color: c.textPrimary),
      displaySmall:   SKTextStyles.d3.copyWith(color: c.textPrimary),
      headlineMedium: SKTextStyles.h1.copyWith(color: c.textPrimary),
      headlineSmall:  SKTextStyles.h2.copyWith(color: c.textPrimary),
      titleLarge:  SKTextStyles.h3.copyWith(color: c.textPrimary),
      bodyLarge:   SKTextStyles.bodyL.copyWith(color: c.textPrimary),
      bodyMedium:  SKTextStyles.body.copyWith(color: c.textPrimary),
      bodySmall:   SKTextStyles.small.copyWith(color: c.textSecondary),
      labelLarge:  SKTextStyles.body.copyWith(
        fontWeight: FontWeight.w600, color: c.textPrimary,
      ),
      labelMedium: SKTextStyles.small.copyWith(
        fontWeight: FontWeight.w600, color: c.textSecondary,
      ),
      labelSmall:  SKTextStyles.micro.copyWith(color: c.textTertiary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.bg,

      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary:     c.cta,
        onPrimary:   Colors.white,
        secondary:   c.accent,
        onSecondary: Colors.white,
        error:       c.danger,
        onError:     Colors.white,
        surface:     c.elevated,
        onSurface:   c.textPrimary,
      ),

      textTheme: tt,

      // ── Buttons ──────────────────────────────────────────────────────────

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 56)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SKRadius.pill),
            ),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return c.textDisabled;
            if (states.contains(WidgetState.pressed))  return c.ctaPressed;
            return c.cta;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return c.textTertiary;
            return Colors.white;
          }),
          textStyle: WidgetStatePropertyAll(tt.labelLarge),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 56)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SKRadius.pill),
            ),
          ),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return c.bg;
            return c.elevated;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return c.textDisabled;
            return c.textPrimary;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: c.hairline)),
          textStyle: WidgetStatePropertyAll(tt.labelLarge),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SKRadius.pill),
            ),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return c.textDisabled;
            if (states.contains(WidgetState.pressed))  return c.ctaPressed;
            return c.cta;
          }),
          textStyle: WidgetStatePropertyAll(tt.labelLarge),
        ),
      ),

      // ── App bar ───────────────────────────────────────────────────────────

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.bg,
        foregroundColor: c.textPrimary,
        titleTextStyle: tt.titleLarge,
        iconTheme: IconThemeData(color: c.textPrimary, size: 24),
      ),

      // ── Input ─────────────────────────────────────────────────────────────

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SKSpacing.x4,
          vertical: SKSpacing.x3,
        ),
        hintStyle:  tt.bodyLarge?.copyWith(color: c.textTertiary),
        labelStyle: tt.labelMedium,
        helperStyle: tt.labelMedium,
        errorStyle: tt.labelMedium?.copyWith(color: c.danger),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SKRadius.md),
          borderSide: BorderSide(color: c.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SKRadius.md),
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SKRadius.md),
          borderSide: BorderSide(color: c.cta, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SKRadius.md),
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SKRadius.md),
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SKRadius.md),
          borderSide: BorderSide(color: c.hairline),
        ),
      ),

      // ── Navigation bar ───────────────────────────────────────────────────
      // GlassBottomNav is the primary nav — this theme keeps Material
      // NavigationBar widgets consistent if used anywhere.

      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: c.elevated,
        indicatorColor: c.accent,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SKRadius.pill),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tt.labelMedium!.copyWith(color: c.cta);
          }
          return tt.labelMedium!.copyWith(color: c.textSecondary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.cta, size: 22);
          }
          return IconThemeData(color: c.textSecondary, size: 22);
        }),
      ),

      // ── Snack bar ─────────────────────────────────────────────────────────
      // c.inverse gives a dark bg in light mode and a warm-white bg in dark;
      // c.bg inverts to a readable text color on both.

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inverse,
        contentTextStyle: tt.bodyLarge?.copyWith(color: c.bg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SKRadius.md),
        ),
      ),

      // ── Card ──────────────────────────────────────────────────────────────

      cardTheme: CardThemeData(
        color: c.elevated,
        margin: EdgeInsets.zero,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SKRadius.lg),
          side: BorderSide(color: c.hairline, width: 0.5),
        ),
      ),

      // ── Bottom sheet ──────────────────────────────────────────────────────

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.elevated,
        modalBackgroundColor: c.elevated,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: c.divider,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SKRadius.xl),
          ),
        ),
      ),

      // ── Dialog ────────────────────────────────────────────────────────────

      dialogTheme: DialogThemeData(
        backgroundColor: c.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SKRadius.xl),
        ),
        titleTextStyle: tt.titleLarge,
        contentTextStyle: tt.bodyMedium?.copyWith(color: c.textSecondary),
      ),

      // ── Popup menu ────────────────────────────────────────────────────────

      popupMenuTheme: PopupMenuThemeData(
        color: c.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SKRadius.lg),
          side: BorderSide(color: c.hairline),
        ),
        textStyle: tt.bodyMedium,
      ),

      // ── Date picker ───────────────────────────────────────────────────────

      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.elevated,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.bg,
        headerForegroundColor: c.textPrimary,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))  return Colors.white;
          if (states.contains(WidgetState.disabled))  return c.textDisabled;
          return c.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.cta;
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return c.cta;
        }),
        todayBorder: BorderSide(color: c.cta),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return c.textPrimary;
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.cta;
          return Colors.transparent;
        }),
        dividerColor: c.hairline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SKRadius.xl),
        ),
      ),

      // ── Misc ──────────────────────────────────────────────────────────────

      dividerColor: c.hairline,
      disabledColor: c.textDisabled,
      splashColor: c.accentSoft,
      highlightColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
