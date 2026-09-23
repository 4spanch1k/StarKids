import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'di/service_registry.dart';
import 'account_state_coordinator.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'router/notification_navigation_coordinator.dart';
import 'theme/app_theme.dart';
import '../core/design_system/sk_color_scheme.dart';
import '../core/design_system/sk_theme.dart';
import '../core/design_system/widgets/sk_splash_view.dart';
import '../features/auth/presentation/controllers/mobile_auth_controller.dart';
import '../features/auth/domain/mobile_auth_session.dart';
import '../features/auth/presentation/pages/email_auth_gate_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/tickets/domain/ticket_purchase.dart';
import '../features/tickets/presentation/controllers/payment_return_coordinator.dart';
import '../features/tickets/presentation/models/tickets_page_args.dart';

final String _requestedLaunchRoute =
    WidgetsBinding.instance.platformDispatcher.defaultRouteName;
const String _configuredLaunchRoute = String.fromEnvironment(
  'STARKIDS_INITIAL_ROUTE',
  defaultValue: '',
);

class StarKidsApp extends StatefulWidget {
  const StarKidsApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  State<StarKidsApp> createState() => _StarKidsAppState();
}

class _StarKidsAppState extends State<StarKidsApp> {
  StreamSubscription<PaymentReturnEvent>? _paymentReturnSubscription;
  late final AccountStateCoordinator _accountStateCoordinator;
  final _unauthenticatedNavigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _accountStateCoordinator = AccountStateCoordinator(
      authListenable: ServiceRegistry.mobileAuthController,
      readIdentity: () => _accountIdentity(
        ServiceRegistry.mobileAuthController.session,
      ),
      profileController: ServiceRegistry.profileController,
      childrenController: ServiceRegistry.childrenController,
    );
    _paymentReturnSubscription =
        ServiceRegistry.paymentReturnCoordinator.events.listen(
      _handlePaymentReturn,
    );
    unawaited(ServiceRegistry.paymentReturnCoordinator.start());
  }

  @override
  void dispose() {
    _accountStateCoordinator.dispose();
    unawaited(_paymentReturnSubscription?.cancel());
    super.dispose();
  }

  String? _accountIdentity(MobileAuthSession? session) {
    return session?.user?.id ?? session?.email ?? session?.phone;
  }

  void _handlePaymentReturn(PaymentReturnEvent event) {
    if (!mounted ||
        ServiceRegistry.paymentReturnCoordinator.hasCheckoutListener) {
      return;
    }

    final navigator = StarKidsApp.navigatorKey.currentState;
    if (event.isPaid) {
      navigator?.pushNamedAndRemoveUntil(
        AppRoutes.tickets,
        (route) => false,
        arguments: TicketsPageArgs(
          initialSection: event.checkoutKind == PaymentCheckoutKind.pass
              ? TicketsSection.passes
              : TicketsSection.tickets,
        ),
      );
      return;
    }

    final messenger = StarKidsApp.scaffoldMessengerKey.currentState;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          event.errorMessage ??
              switch (event.status?.status) {
                TicketPaymentStatusValue.failed ||
                TicketPaymentStatusValue.canceled ||
                TicketPaymentStatusValue.expired =>
                  event.status?.failureReason ??
                      'Оплата не прошла. Можно попробовать еще раз.',
                _ =>
                  'Платеж еще обрабатывается. Повторите проверку чуть позже.',
              },
        ),
      ),
    );
  }

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
        final isBootstrapping = authController.session == null &&
            (authController.status == MobileAuthStatus.idle ||
                authController.status == MobileAuthStatus.loading);
        final isAuthenticated = authController.isAuthenticated;
        debugPrint(
          '[APP] rendering '
          '${isAuthenticated ? 'home' : isBootstrapping ? 'loading' : 'auth'}',
        );

        return MaterialApp(
          key: ValueKey(
            isAuthenticated
                ? 'authenticated-app-${onboarding.isRequired}'
                : 'auth-gate',
          ),
          title: 'Boom Bala',
          // Do not reuse the authenticated navigator's route stack for the
          // unauthenticated shell (or vice versa). MaterialApp rebuilds when
          // auth changes, but a shared navigator key can preserve the old
          // auth/loading route and leave it visible after a successful OTP.
          navigatorKey: isAuthenticated
              ? StarKidsApp.navigatorKey
              : _unauthenticatedNavigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          scaffoldMessengerKey: StarKidsApp.scaffoldMessengerKey,
          builder: (ctx, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final navigator = StarKidsApp.navigatorKey.currentState;
              if (navigator != null) {
                NotificationNavigationCoordinator.instance.attach(
                  navigator: navigator,
                  authenticated: isAuthenticated && !onboarding.isRequired,
                  scaffoldMessenger:
                      StarKidsApp.scaffoldMessengerKey.currentState,
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
              : onboarding.isRequired
                  ? const OnboardingPage()
                  : null,
          initialRoute: isAuthenticated && !onboarding.isRequired
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
