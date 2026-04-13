import 'package:flutter/material.dart';

import 'di/service_registry.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'theme/app_theme.dart';
import '../features/auth/presentation/controllers/mobile_auth_controller.dart';
import '../features/auth/presentation/pages/email_auth_gate_page.dart';

class StarKidsApp extends StatelessWidget {
  const StarKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.mobileAuthController,
      builder: (context, _) {
        final authController = ServiceRegistry.mobileAuthController;
        final isBootstrapping =
            authController.status == MobileAuthStatus.loading &&
                authController.session == null;
        final isAuthenticated = authController.isAuthenticated;

        return MaterialApp(
          key: ValueKey(isAuthenticated ? 'authenticated-app' : 'auth-gate'),
          title: 'Star Kids',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: !isAuthenticated
              ? isBootstrapping
                  ? const _AuthGateLoadingPage()
                  : const EmailAuthGatePage()
              : null,
          initialRoute: isAuthenticated
              ? ServiceRegistry.selectedBranchController.hasStoredSelection
                  ? AppRoutes.home
                  : AppRoutes.onboarding
              : null,
          onGenerateRoute: isAuthenticated ? AppRouter.onGenerateRoute : null,
        );
      },
    );
  }
}

class _AuthGateLoadingPage extends StatelessWidget {
  const _AuthGateLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
