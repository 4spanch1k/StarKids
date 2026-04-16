import 'package:flutter/material.dart';

abstract final class StarKidsColors {
  static const Color brandPrimary = Color(0xFFEB0876);
  static const Color brandPrimaryPressed = Color(0xFFC70662);
  static const Color brandSecondary = Color(0xFF09A284);
  static const Color brandAccent = Color(0xFFF29F24);
  static const Color brandHighlight = Color(0xFFFAEB0B);

  static const Color actionDisabledBg = Color(0xFFF2E8ED);
  static const Color actionDisabledFg = Color(0xFFC9C1C8);

  // Cosmic palette — soft pastel nebula tones
  static const Color cosmicBlush = Color(0xFFFFD6E8); // soft pink
  static const Color cosmicLavender = Color(0xFFE8D6FF); // lavender
  static const Color cosmicPeach = Color(0xFFFFE4D6); // peach
  static const Color cosmicSky = Color(0xFFD6EEFF); // sky blue
  static const Color cosmicMint = Color(0xFFD6FFF0); // mint

  // Glass surfaces — light mode
  static const Color glassSurface = Color(0xBFFFFFFF); // 75% white
  static const Color glassStroke = Color(0x28EB0876); // 16% brand pink
  static const Color glassHighlight = Color(0x33FFFFFF); // 20% white sheen

  // Cosmic background — barely-there lavender-white
  static const Color cosmicBg = Color(0xFFF8F5FF);

  static const Color surfaceCanvas = Color(0xFFF8F5FF);
  static const Color surfacePrimary = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFFFF1E3);
  static const Color surfaceTertiary = Color(0xFFFCE3EF);
  static const Color surfaceInverse = Color(0xFF171316);

  static const Color textPrimary = Color(0xFF171316);
  static const Color textSecondary = Color(0xFF6E6572);
  static const Color textInverse = Color(0xFFFFFFFF);
  static const Color textDisabled = Color(0xFFA69EA6);

  static const Color borderDefault = Color(0xFFE9DDE4);
  static const Color borderStrong = Color(0xFFDCC5D3);
  static const Color borderFocus = Color(0xFFEB0876);
  static const Color borderError = Color(0xFFD6455D);

  static const Color statusSuccess = Color(0xFF1C9A6D);
  static const Color statusSuccessSurface = Color(0xFFE6F7F0);
  static const Color statusWarning = Color(0xFFF29F24);
  static const Color statusWarningSurface = Color(0xFFFFF2E2);
  static const Color statusError = Color(0xFFD6455D);
  static const Color statusErrorSurface = Color(0xFFFDEBED);

  static const Color overlayScrim = Color(0x99171316);
  static const Color overlayImageTop = Color(0x33171316);
  static const Color overlayImageBottom = Color(0x80171316);
}

/// Dark-mode colour tokens — deep cosmic indigo palette.
abstract final class StarKidsDarkColors {
  // Backgrounds
  static const Color bg = Color(0xFF0B0B1E); // deep indigo
  static const Color surfaceCanvas = Color(0xFF0B0B1E);
  static const Color surfacePrimary = Color(0xFF121225); // slightly lifted
  static const Color surfaceElevated = Color(0xFF191936); // cards / sheets
  static const Color surfaceInverse =
      Color(0xFFF0ECF8); // inverse (light on dark)

  // Glass surfaces
  static const Color glassSurface = Color(0x14FFFFFF); // 8% white glass
  static const Color glassStroke = Color(0x28FFFFFF); // 16% white border
  static const Color glassHighlight = Color(0x0DFFFFFF); // 5% sheen at top

  // Nebula blobs (dark analogues)
  static const Color nebulaViolet = Color(0x33A855F7); // neon purple 20%
  static const Color nebulaBlue = Color(0x1A3B82F6); // electric blue 10%
  static const Color nebulaEmerald = Color(0x1A10B981); // emerald drop 10%

  // Text
  static const Color textPrimary = Color(0xFFF0ECF8); // off-white
  static const Color textSecondary = Color(0xFF9B94B8); // grey-blue
  static const Color textDisabled = Color(0xFF5A5478);

  // Borders
  static const Color borderDefault = Color(0xFF2A2645);
  static const Color borderStrong = Color(0xFF3D3860);
  static const Color borderFocus = Color(0xFFFF0F90); // vivid pink
  static const Color borderError = Color(0xFFFF6B6B);

  // Accents
  static const Color accentPink = Color(0xFFFF0F90); // vivid pink
  static const Color accentBlue = Color(0xFF4D9FFF); // electric blue
  static const Color brandPrimary = Color(0xFFFF0F90); // brighter in dark

  // Status
  static const Color statusSuccess = Color(0xFF34D399);
  static const Color statusSuccessSurface = Color(0xFF0D3D2E);
  static const Color statusWarning = Color(0xFFFBBF24);
  static const Color statusWarningSurface = Color(0xFF3D2F00);
  static const Color statusError = Color(0xFFFF6B6B);
  static const Color statusErrorSurface = Color(0xFF3D0F0F);

  // Action states
  static const Color actionDisabledBg = Color(0xFF1E1B35);
  static const Color actionDisabledFg = Color(0xFF4A4568);

  // Nav bar
  static const Color navBarBg = Color(0x99121225); // 60% dark surface
  static const Color navIndicator = Color(0x33FF0F90); // glow indicator
}
