import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:star_kids_mobile/app/theme/app_theme.dart';
import 'package:star_kids_mobile/core/design_system/sk_color_scheme.dart';
import 'package:star_kids_mobile/core/design_system/sk_theme.dart';

Widget buildTestApp({
  required Widget child,
  Locale locale = const Locale('ru'),
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    locale: locale,
    supportedLocales: const [
      Locale('ru'),
      Locale('kk'),
    ],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, appChild) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return SKTheme(
        dark: isDark,
        colors: isDark ? SKColorScheme.dark() : SKColorScheme.light(),
        child: appChild!,
      );
    },
    home: child,
  );
}
