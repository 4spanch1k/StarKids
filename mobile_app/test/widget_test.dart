import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/app/bootstrap/star_kids_bootstrap_app.dart';
import 'package:star_kids_mobile/app/app.dart';
import 'package:star_kids_mobile/app/di/service_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServiceRegistry.mobileAuthController.logout();
  });

  testWidgets('unauthenticated app opens email auth gate', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const StarKidsApp());
    await tester.pumpAndSettle();

    expect(find.text('Star Kids'), findsOneWidget);
    expect(find.text('Вход'), findsWidgets);
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.text('Продолжить с Google'), findsOneWidget);

    const hasClerkPublishableKey = String.fromEnvironment(
          'MOBILE_CLERK_PUBLISHABLE_KEY',
          defaultValue: '',
        ) !=
        '';
    expect(
      find.text('Google вход недоступен: не задан Clerk publishable key.'),
      hasClerkPublishableKey ? findsNothing : findsOneWidget,
    );

    await tester.tap(find.text('Войти').last);
    await tester.pumpAndSettle();

    expect(find.text('Введите электронную почту.'), findsOneWidget);
    expect(find.text('Введите пароль.'), findsOneWidget);
  });

  testWidgets('bootstrap shell leaves splash after initialization completes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      StarKidsBootstrapApp(
        initialize: () async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Star Kids'), findsOneWidget);
    expect(find.text('Вход'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
  });
}
