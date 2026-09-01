import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'di/service_registry.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'theme/app_theme.dart';
import '../core/design_system/sk_color_scheme.dart';
import '../core/design_system/sk_theme.dart';
import '../core/design_system/widgets/sk_splash_view.dart';
import '../features/auth/presentation/controllers/mobile_auth_controller.dart';
import '../features/auth/presentation/pages/email_auth_gate_page.dart';

final String _requestedLaunchRoute =
    WidgetsBinding.instance.platformDispatcher.defaultRouteName;
const String _configuredLaunchRoute = String.fromEnvironment(
  'STARKIDS_INITIAL_ROUTE',
  defaultValue: '',
);

class StarKidsApp extends StatelessWidget {
  const StarKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Capture this before the temporary unauthenticated bootstrap shell can
    // consume and reset Flutter's platform-provided launch route.
    final requestedLaunchRoute = _configuredLaunchRoute.isNotEmpty
        ? _configuredLaunchRoute
        : _requestedLaunchRoute;
    return AnimatedBuilder(
      animation: Listenable.merge([
        ServiceRegistry.mobileAuthController,
        ServiceRegistry.appSettingsController,
      ]),
      builder: (context, _) {
        final authController = ServiceRegistry.mobileAuthController;
        final settings = ServiceRegistry.appSettingsController;
        final isBootstrapping =
            authController.status == MobileAuthStatus.loading &&
                authController.session == null;
        final isAuthenticated = authController.isAuthenticated;
        debugPrint(
          '[APP] rendering '
          '${isAuthenticated ? 'home' : isBootstrapping ? 'loading' : 'auth'}',
        );

        return MaterialApp(
          key: ValueKey(isAuthenticated ? 'authenticated-app' : 'auth-gate'),
          title: 'Boom Bala',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          builder: (ctx, child) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return SKTheme(
              dark: isDark,
              colors: isDark ? SKColorScheme.dark() : SKColorScheme.light(),
              child: child!,
            );
          },
          locale: Locale(settings.locale),
          supportedLocales: const [
            Locale('ru'),
            Locale('kk'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: !isAuthenticated
              ? isBootstrapping
                  ? const _AuthGateLoadingPage()
                  : const EmailAuthGatePage()
              : null,
          initialRoute: isAuthenticated
              ? _authenticatedInitialRoute(requestedLaunchRoute)
              : AppRoutes.onboarding,
          onGenerateRoute: isAuthenticated ? AppRouter.onGenerateRoute : null,
        );
      },
    );
  }

  String _authenticatedInitialRoute(String requestedRoute) {
    const authenticatedRoutes = {
      AppRoutes.home,
      AppRoutes.birthdays,
      AppRoutes.afisha,
      AppRoutes.promotions,
      AppRoutes.tickets,
      AppRoutes.profile,
      AppRoutes.menu,
      AppRoutes.contacts,
      AppRoutes.branchDetails,
      AppRoutes.requests,
      AppRoutes.notifications,
      AppRoutes.myRequests,
    };
    return authenticatedRoutes.contains(requestedRoute)
        ? requestedRoute
        : AppRoutes.home;
  }
}

class _AuthGateLoadingPage extends StatelessWidget {
  const _AuthGateLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const SkSplashView();
  }
}
