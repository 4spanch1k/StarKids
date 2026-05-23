// lib/core/design_system/sk_color_scheme.dart
//
// Liquid Glass color tokens for Star Kids.
// Raw palette + resolved light/dark scheme used by all new glass widgets.
// Existing StarKidsColors / SK tokens remain unchanged.

import 'package:flutter/material.dart';

/// Raw color palette — single source of truth.
abstract final class SKColors {
  // ── Cream (warm base) ──────────────────────────────────────────────────
  static const cream50  = Color(0xFFFDFBF7);
  static const cream100 = Color(0xFFFAF7F2); // app background light
  static const cream200 = Color(0xFFF2EDE4);
  static const cream300 = Color(0xFFE8E1D4);
  static const cream400 = Color(0xFFD4CBB9);

  // ── Graphite (text + dark surfaces) ───────────────────────────────────
  static const graphite50  = Color(0xFFF4F2EE);
  static const graphite100 = Color(0xFFE2DED7);
  static const graphite400 = Color(0xFF6B655C);
  static const graphite600 = Color(0xFF3A352E);
  static const graphite800 = Color(0xFF211E19); // text primary light
  static const graphite900 = Color(0xFF14110D); // app background dark

  // ── Coral (warm brand accent) ──────────────────────────────────────────
  static const coral100 = Color(0xFFFFE7E5);
  static const coral300 = Color(0xFFFFB3AE);
  static const coral500 = Color(0xFFFF6B6B);
  static const coral600 = Color(0xFFE85C5A); // brand accent
  static const coral700 = Color(0xFFC84846);

  // ── CTA Blue — ALL primary actions must use this ───────────────────────
  static const blue100 = Color(0xFFDBE8FF);
  static const blue500 = Color(0xFF2563EB); // PRIMARY CTA
  static const blue600 = Color(0xFF1D55D6);
  static const blue700 = Color(0xFF1B49B5); // pressed

  // ── Semantic ───────────────────────────────────────────────────────────
  static const mint500   = Color(0xFF0EA572); // success
  static const mint100   = Color(0xFFD7F0E5);
  static const amber500  = Color(0xFFF59E0B); // warning
  static const amber100  = Color(0xFFFFEFCB);
  static const danger500 = Color(0xFFDC2626); // destructive
  static const danger100 = Color(0xFFFFE1DC);
}

/// Resolved color tokens for the active theme.
/// Access via [SKTheme.of(context).colors] — never instantiate directly.
class SKColorScheme {
  final Color bg;
  final Color elevated;
  final Color raised;
  final Color inverse;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  final Color accent;
  final Color accentSoft;

  final Color cta;
  final Color ctaPressed;
  final Color ctaSoft;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  final Color divider;
  final Color hairline;

  // Glass tints applied behind BackdropFilter.
  final Color glassTint;
  final Color glassTint2;
  final Color glassBorder;
  final Color glassShine;

  const SKColorScheme._({
    required this.bg,
    required this.elevated,
    required this.raised,
    required this.inverse,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.accent,
    required this.accentSoft,
    required this.cta,
    required this.ctaPressed,
    required this.ctaSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.divider,
    required this.hairline,
    required this.glassTint,
    required this.glassTint2,
    required this.glassBorder,
    required this.glassShine,
  });

  factory SKColorScheme.light() => const SKColorScheme._(
    bg:            SKColors.cream100,
    elevated:      Colors.white,
    raised:        Colors.white,
    inverse:       SKColors.graphite900,
    textPrimary:   SKColors.graphite800,
    textSecondary: Color(0x9E211E19), // 62%
    textTertiary:  Color(0x66211E19), // 40%
    textDisabled:  Color(0x47211E19), // 28%
    accent:        SKColors.coral600,
    accentSoft:    SKColors.coral100,
    cta:           SKColors.blue500,
    ctaPressed:    SKColors.blue700,
    ctaSoft:       SKColors.blue100,
    success:       SKColors.mint500,
    successSoft:   SKColors.mint100,
    warning:       SKColors.amber500,
    warningSoft:   SKColors.amber100,
    danger:        SKColors.danger500,
    dangerSoft:    SKColors.danger100,
    divider:       Color(0x0F211E19), // 6%
    hairline:      Color(0x14211E19), // 8%
    glassTint:     Color(0x52FFFCF7), // ~32% warm white — lets blur show
    glassTint2:    Color(0x38FFF5EB), // ~22%
    glassBorder:   Color(0x33FFFFFF), // 20% white pearl edge
    glassShine:    Color(0xA8FFFFFF), // 66% top highlight
  );

  factory SKColorScheme.dark() => const SKColorScheme._(
    bg:            SKColors.graphite900,
    elevated:      Color(0xFF1B1813),
    raised:        Color(0xFF23201A),
    inverse:       Color(0xFFF5F1EA),
    textPrimary:   Color(0xFFF5F1EA),
    textSecondary: Color(0xADF5F1EA), // 68%
    textTertiary:  Color(0x73F5F1EA), // 45%
    textDisabled:  Color(0x47F5F1EA),
    accent:        Color(0xFFFF7A78), // lifted coral on dark
    accentSoft:    Color(0x2EFF6B6B),
    cta:           Color(0xFF3B82F6),
    ctaPressed:    SKColors.blue700,
    ctaSoft:       Color(0x2E2563EB),
    success:       SKColors.mint500,
    successSoft:   Color(0x2E0EA572),
    warning:       SKColors.amber500,
    warningSoft:   Color(0x2EF59E0B),
    danger:        Color(0xFFEF4444),
    dangerSoft:    Color(0x2EDC2626),
    divider:       Color(0x12FFFFFF),
    hairline:      Color(0x1AFFFFFF),
    glassTint:     Color(0x5C28241E), // ~36% dark brown — lets blur show
    glassTint2:    Color(0x4A3C362E), // ~29%
    glassBorder:   Color(0x3DFFFFFF), // 24% white
    glassShine:    Color(0x2DFFFFFF), // 18%
  );
}
