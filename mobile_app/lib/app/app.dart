import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'di/service_registry.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'router/notification_navigation_coordinator.dart';
import 'theme/app_theme.dart';
import '../core/design_system/sk_color_scheme.dart';
import '../core/design_system/sk_theme.dart';
import '../core/design_system/widgets/sk_splash_view.dart';
import '../features/auth/presentation/controllers/mobile_auth_controller.dart';
import '../features/auth/presentation/pages/email_auth_gate_page.dart';
import '../features/onboarding/presentation/controllers/onboarding_controller.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';

final String _requestedLaunchRoute =
    WidgetsBinding.instance.platformDispatcher.defaultRouteName;
const String _configuredLaunchRoute = String.fromEnvironment(
  'STARKIDS_INITIAL_ROUTE',
  defaultValue: '',
);

class StarKidsApp extends StatelessWidget {
  const StarKidsApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

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
        ServiceRegistry.onboardingController,
      ]),
      builder: (context, _) {
        final authController = ServiceRegistry.mobileAuthController;
        final settings = ServiceRegistry.appSettingsController;
        final onboarding = ServiceRegistry.onboardingController;
        final isBootstrapping =
            authController.status == MobileAuthStatus.loading &&
                authController.session == null;
        final isAuthenticated = authController.isAuthenticated;
        final isOnboardingResolved =
            onboarding.isComplete || onboarding.isRequired;
        debugPrint(
          '[APP] rendering '
          '${isAuthenticated ? 'home' : isBootstrapping ? 'loading' : 'auth'}',
        );

        return MaterialApp(
          key: ValueKey(isAuthenticated ? 'authenticated-app' : 'auth-gate'),
          title: 'Boom Bala',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          builder: (ctx, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final navigator = navigatorKey.currentState;
              if (navigator != null) {
                NotificationNavigationCoordinator.instance.attach(
                  navigator: navigator,
                  authenticated: isAuthenticated,
                );
              }
            });
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
              : !isOnboardingResolved
                  ? onboarding.status == OnboardingStatus.error
                      ? _OnboardingBootstrapErrorPage(
                          message: onboarding.errorMessage,
                          onRetry: onboarding.retry,
                        )
                      : const _AuthGateLoadingPage()
                  : onboarding.isRequired
                      ? const OnboardingPage()
                      : null,
          initialRoute: isAuthenticated && onboarding.isComplete
              ? _authenticatedInitialRoute(requestedLaunchRoute)
              : null,
          onGenerateRoute: isAuthenticated ? AppRouter.onGenerateRoute : null,
        );
      },
    );
  }

  String _authenticatedInitialRoute(String requestedRoute) {
    const authenticatedRoutes = {
      AppRoutes.home,
      AppRoutes.birthdays,
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

class _OnboardingBootstrapErrorPage extends StatelessWidget {
  const _OnboardingBootstrapErrorPage({
    required this.message,
    required this.onRetry,
  });

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Не удалось загрузить профиль семьи.'),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
