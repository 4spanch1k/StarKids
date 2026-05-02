import 'package:flutter/material.dart';

abstract final class StarKidsShadows {
  static const List<BoxShadow> depth1 = [
    BoxShadow(
      color: Color(0x14171316),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> depth1Dark = [
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
  ];

  static const List<BoxShadow> depth2 = [
    BoxShadow(
      color: Color(0x1A171316),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> depth3 = [
    BoxShadow(
      color: Color(0x24171316),
      blurRadius: 40,
      offset: Offset(0, 18),
    ),
  ];

  // Soft coral-tinted card shadow.
  static const List<BoxShadow> cosmicCard = [
    BoxShadow(
      color: Color(0x20FF5A5F),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0C171316),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  // Floating nav bar shadow.
  static const List<BoxShadow> navFloat = [
    BoxShadow(
      color: Color(0x24FF5A5F),
      blurRadius: 32,
      offset: Offset(0, -4),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Color(0x18171316),
      blurRadius: 20,
      offset: Offset(0, -2),
    ),
  ];

  static const List<BoxShadow> navFloatDark = [
    BoxShadow(
      color: Color(0x20FF5A5F),
      blurRadius: 16,
      offset: Offset(0, -2),
      spreadRadius: -6,
    ),
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  // Icon glow for quick-action tiles
  static const List<BoxShadow> iconGlow = [
    BoxShadow(
      color: Color(0x33FF5A5F),
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  // Brand button glow
  static const List<BoxShadow> brandGlow = [
    BoxShadow(
      color: Color(0x38FF5A5F),
      blurRadius: 26,
      offset: Offset(0, 14),
    ),
  ];
}
