import 'package:flutter/material.dart';

import 'di/service_registry.dart';
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
      initialRoute: ServiceRegistry.selectedBranchController.hasStoredSelection
          ? AppRoutes.home
          : AppRoutes.onboarding,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
