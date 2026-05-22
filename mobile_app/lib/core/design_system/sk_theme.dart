// lib/core/design_system/sk_theme.dart
//
// SKTheme — InheritedWidget that exposes SKColorScheme to the widget tree.
// Wire it in app.dart via MaterialApp.builder (already done in Step 2).
//
// Usage in widgets:
//   final c = SKTheme.of(context).colors;
//   Container(color: c.bg, ...);
//
// NOTE: buildMaterialTheme() is NOT yet wired as AppTheme.
// It will replace StarKidsTheme in Step 4 once all existing widgets
// have been verified to work with Plus Jakarta Sans + Bricolage Grotesque.

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

  /// Access the nearest SKTheme in the tree.
  /// Throws if SKTheme is not in the ancestor chain — add it in app.dart.
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

  // ── Material ThemeData ─────────────────────────────────────────────────
  //
  // Builds a full ThemeData using Plus Jakarta Sans (body) +
  // Bricolage Grotesque (display/headline). Will replace StarKidsTheme
  // in Step 4. Until then this factory is available but unused.

  static ThemeData buildMaterialTheme({required bool dark}) {
    final c = dark ? SKColorScheme.dark() : SKColorScheme.light();

    // Plus Jakarta Sans applied to the full base text theme; Bricolage
    // Grotesque overrides the display/headline slots below.
    final base = GoogleFonts.plusJakartaSansTextTheme(
      dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary:     c.cta,          // solid blue #2563EB
        onPrimary:   Colors.white,
        secondary:   c.accent,       // coral
        onSecondary: Colors.white,
        error:       c.danger,
        onError:     Colors.white,
        surface:     c.elevated,
        onSurface:   c.textPrimary,
      ),
      textTheme: base.copyWith(
        // Display — Bricolage Grotesque
        displayLarge:   SKTextStyles.d1.copyWith(color: c.textPrimary),
        displayMedium:  SKTextStyles.d2.copyWith(color: c.textPrimary),
        displaySmall:   SKTextStyles.d3.copyWith(color: c.textPrimary),
        headlineMedium: SKTextStyles.h1.copyWith(color: c.textPrimary),
        headlineSmall:  SKTextStyles.h2.copyWith(color: c.textPrimary),
        // Body / labels — Plus Jakarta Sans
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
      ),
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
