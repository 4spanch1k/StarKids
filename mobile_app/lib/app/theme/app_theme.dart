import 'package:flutter/material.dart';

import 'star_kids_theme.dart';

abstract final class AppTheme {
  static ThemeData light() => StarKidsTheme.light();
  static ThemeData dark() => StarKidsTheme.dark();
}
