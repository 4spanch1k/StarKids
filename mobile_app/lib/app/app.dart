import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'theme/app_theme.dart';

class StarKidsApp extends StatelessWidget {
  const StarKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Star Kids',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.onboarding,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

