import 'package:flutter/material.dart';

abstract final class StarKidsShadows {
  static const List<BoxShadow> depth1 = [
    BoxShadow(
      color: Color(0x14171316),
      blurRadius: 12,
      offset: Offset(0, 4),
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
}
