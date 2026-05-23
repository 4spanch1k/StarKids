// lib/core/design_system/sk_design_tokens.dart
//
// Liquid Glass design tokens — spacing, radius, shadows, blur, motion, type.
// Use these in all new glass widgets. Existing StarKidsSpacing / StarKidsRadii
// / StarKidsShadows / SK remain unchanged for backward compatibility.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Typography ──────────────────────────────────────────────────────────────

abstract final class SKTypography {
  static const display = 'Bricolage Grotesque';
  static const body    = 'Plus Jakarta Sans';
  // Reuse bundled GeistMono for technical/meta details — no network needed.
  static const mono    = 'GeistMono';
}

/// Text style helpers — getters so Google Fonts can resolve lazily.
/// Colors are NOT baked in; always call [copyWith(color: c.textPrimary)].
abstract final class SKTextStyles {
  // Display — Bricolage Grotesque
  static TextStyle get d1 => GoogleFonts.bricolageGrotesque(
    fontSize: 40, fontWeight: FontWeight.w800,
    letterSpacing: -1.0, height: 1.05,
  );
  static TextStyle get d2 => GoogleFonts.bricolageGrotesque(
    fontSize: 32, fontWeight: FontWeight.w700,
    letterSpacing: -0.6, height: 1.08,
  );
  static TextStyle get d3 => GoogleFonts.bricolageGrotesque(
    fontSize: 26, fontWeight: FontWeight.w700,
    letterSpacing: -0.4, height: 1.10,
  );
  static TextStyle get h1 => GoogleFonts.bricolageGrotesque(
    fontSize: 22, fontWeight: FontWeight.w700,
    letterSpacing: -0.3, height: 1.18,
  );

  // Body — Plus Jakarta Sans
  static TextStyle get h2 => GoogleFonts.plusJakartaSans(
    fontSize: 19, fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );
  static TextStyle get h3 => GoogleFonts.plusJakartaSans(
    fontSize: 17, fontWeight: FontWeight.w700,
  );
  static TextStyle get bodyL => GoogleFonts.plusJakartaSans(
    fontSize: 16, fontWeight: FontWeight.w500, height: 1.45,
  );
  static TextStyle get body => GoogleFonts.plusJakartaSans(
    fontSize: 15, fontWeight: FontWeight.w500, height: 1.45,
  );
  static TextStyle get small => GoogleFonts.plusJakartaSans(
    fontSize: 13, fontWeight: FontWeight.w500,
  );
  static TextStyle get micro => GoogleFonts.plusJakartaSans(
    fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6,
  );

  // Mono — bundled GeistMono (no network download)
  static const mono = TextStyle(
    fontFamily: 'GeistMono', fontSize: 12,
    fontWeight: FontWeight.w500, letterSpacing: 0.5,
  );
}

// ── Spacing (4-pt scale) ────────────────────────────────────────────────────

abstract final class SKSpacing {
  static const x1  = 4.0;
  static const x2  = 8.0;
  static const x3  = 12.0;
  static const x4  = 16.0;
  static const x5  = 20.0;
  static const x6  = 24.0;
  static const x7  = 28.0;
  static const x8  = 32.0;
  static const x10 = 40.0;
  static const x12 = 48.0;
  static const gutter    = 16.0;
  static const tapTarget = 44.0; // a11y minimum
}

// ── Radius ──────────────────────────────────────────────────────────────────

abstract final class SKRadius {
  static const xs   = 6.0;
  static const sm   = 10.0;
  static const md   = 14.0;
  static const lg   = 22.0; // default card
  static const xl   = 28.0; // hero, sheets
  static const pill = 9999.0;
}

// ── Shadows / elevation ─────────────────────────────────────────────────────

abstract final class SKShadows {
  static const sm = [
    BoxShadow(color: Color(0x0A211E19), blurRadius: 2,  offset: Offset(0, 1)),
  ];
  static const md = [
    BoxShadow(color: Color(0x10211E19), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const lg = [
    BoxShadow(color: Color(0x17211E19), blurRadius: 40, offset: Offset(0, 18)),
  ];
  static const pill = [
    BoxShadow(color: Color(0x1A211E19), blurRadius: 22, offset: Offset(0, 6)),
  ];
  static const ctaBlue = [
    BoxShadow(color: Color(0x442563EB), blurRadius: 16, offset: Offset(0, 6)),
  ];
}

// ── Blur (direct sigma values, capped at 14 for Android performance) ────────

abstract final class SKBlur {
  static const subtle =  8.0; // app bar strip
  static const base   = 13.0; // default glass (bottom nav)
  static const heavy  = 14.0; // drawer (open infrequently)
  static const max    = 14.0; // absolute ceiling — Android sigma cap

  // Pass directly as ImageFilter.blur(sigmaX: value, sigmaY: value).
}

// ── Opacity tokens ──────────────────────────────────────────────────────────

abstract final class SKOpacity {
  static const glassPanel  = 0.62;
  static const glassPill   = 0.55;
  static const glassDrawer = 0.85;
  static const glassSheet  = 1.00; // sheet body is solid; chrome is glass
  static const scrim       = 0.42;
}

// ── Motion ──────────────────────────────────────────────────────────────────

abstract final class SKMotion {
  static const fast  = Duration(milliseconds: 160);
  static const base  = Duration(milliseconds: 220);
  static const slow  = Duration(milliseconds: 320);
  // ≈ CSS cubic-bezier(0.2, 0.8, 0.2, 1) — snappy deceleration.
  static const curve = Cubic(0.2, 0.8, 0.2, 1.0);
}
