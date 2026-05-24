import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'di/service_registry.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'theme/app_theme.dart';
import '../core/design_system/sk_color_scheme.dart';
import '../core/design_system/sk_theme.dart';
import '../features/auth/presentation/controllers/mobile_auth_controller.dart';
import '../features/auth/presentation/pages/email_auth_gate_page.dart';

class StarKidsApp extends StatelessWidget {
  const StarKidsApp({super.key});

  @override
  Widget build(BuildContext context) {
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
          title: 'Star Kids',
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
          initialRoute: isAuthenticated ? AppRoutes.home : null,
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
