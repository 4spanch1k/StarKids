import 'package:flutter/material.dart';

import '../../core/design_system/sk_theme.dart';

abstract final class AppTheme {
  static ThemeData light() => SKTheme.buildMaterialTheme(dark: false);
  static ThemeData dark()  => SKTheme.buildMaterialTheme(dark: true);
}
