import 'package:flutter/material.dart';

import 'sk_tokens.dart';

abstract final class StarKidsColors {
  // Brand
  static const Color brandPrimary = SK.accent2;
  static const Color brandPrimaryPressed = SK.ink;
  static const Color brandSecondary = Color(0xFF1C9A6D);
  static const Color brandAccent = SK.accent;
  static const Color brandHighlight = SK.sun;

  static const Color actionDisabledBg = Color(0xFFEDE8E4);
  static const Color actionDisabledFg = Color(0xFFC2BAB4);

  static const Color warmSun = SK.sun;
  static const Color warmMint = SK.mint;
  static const Color warmSky = SK.sky;
  static const Color warmPlum = SK.plum;
  static const Color warmCoral = SK.accentSoft;

  // Keep cosmicXxx as aliases pointing to warm equivalents for backwards compat
  static const Color cosmicBlush = SK.accentSoft;
  static const Color cosmicLavender = SK.plum;
  static const Color cosmicPeach = Color(0xFFFFF0E8);
  static const Color cosmicSky = SK.sky;
  static const Color cosmicMint = SK.mint;

  // Glass surfaces (warm-tinted)
  static const Color glassSurface = Color(0xCCFFFFFF); // 80% white
  static const Color glassStroke = Color(0x1A1A1614); // 10% ink
  static const Color glassHighlight = Color(0x33FFFFFF);

  // Background
  static const Color cosmicBg = SK.bg;

  static const Color surfaceCanvas = SK.bg;
  static const Color surfacePrimary = SK.bgElev;
  static const Color surfaceSecondary = SK.bgSoft;
  static const Color surfaceTertiary = SK.accentSoft;
  static const Color surfaceInverse = SK.ink;

  static const Color textPrimary = SK.ink;
  static const Color textSecondary = SK.ink3;
  static const Color textInverse = Colors.white;
  static const Color textDisabled = SK.ink4;

  static const Color borderDefault = SK.line;
  static const Color borderStrong = SK.lineStrong;
  static const Color borderFocus = SK.ink2;
  static const Color borderError = Color(0xFFD6455D);

  static const Color statusSuccess = Color(0xFF1C9A6D);
  static const Color statusSuccessSurface = Color(0xFFE6F7F0);
  static const Color statusWarning = Color(0xFFF29F24);
  static const Color statusWarningSurface = Color(0xFFFFF2E2);
  static const Color statusError = Color(0xFFD6455D);
  static const Color statusErrorSurface = Color(0xFFFDEBED);

  static const Color overlayScrim = Color(0x991A1614);
  static const Color overlayImageTop = Color(0x331A1614);
  static const Color overlayImageBottom = Color(0x801A1614);
}

/// Dark-mode colour tokens.
abstract final class StarKidsDarkColors {
  static const Color bg = SK.darkBg;
  static const Color surfaceCanvas = SK.darkBg;
  static const Color surfacePrimary = SK.darkBgElev;
  static const Color surfaceElevated = SK.darkBgSoft;
  static const Color surfaceInverse = SK.darkInk;

  // Glass surfaces
  static const Color glassSurface = Color(0x14FFFFFF);
  static const Color glassStroke = SK.darkLineStrong;
  static const Color glassHighlight = Color(0x0DFFFFFF);

  // Nebula blobs (dark analogues)
  static const Color nebulaViolet = Color(0x24E5D4F2);
  static const Color nebulaBlue = Color(0x24C7DDEF);
  static const Color nebulaEmerald = Color(0x24B6E3C8);

  static const Color textPrimary = SK.darkInk;
  static const Color textSecondary = SK.darkInk3;
  static const Color textDisabled = Color(0xFF5B504A);

  static const Color borderDefault = SK.darkLine;
  static const Color borderStrong = SK.darkLineStrong;
  static const Color borderFocus = SK.darkInk2;
  static const Color borderError = Color(0xFFFF6B6B);

  static const Color accentPink = SK.accent;
  static const Color accentBlue = SK.sky;
  static const Color brandPrimary = SK.accent;

  // Status
  static const Color statusSuccess = Color(0xFF34D399);
  static const Color statusSuccessSurface = Color(0xFF0D3D2E);
  static const Color statusWarning = Color(0xFFFBBF24);
  static const Color statusWarningSurface = Color(0xFF3D2F00);
  static const Color statusError = Color(0xFFFF6B6B);
  static const Color statusErrorSurface = Color(0xFF3D0F0F);

  // Action states
  static const Color actionDisabledBg = Color(0xFF2A2521);
  static const Color actionDisabledFg = Color(0xFF6D625A);

  static const Color navBarBg = Color(0x991A1715);
  static const Color navIndicator = Color(0x33FF5A5F);
}
