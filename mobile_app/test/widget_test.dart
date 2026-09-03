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

    expect(find.text('Boom Bala'), findsOneWidget);
    expect(find.text('Вход'), findsWidgets);
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.text('Продолжить с Google'), findsOneWidget);

    final passwordField = find.descendant(
      of: find.byKey(const ValueKey('auth-password-field')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);

    await tester.enterText(passwordField, 'copied-password');
    await tester.tap(
      find.byKey(const ValueKey('auth-password-visibility-toggle')),
    );
    await tester.pump();

    expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
    expect(
      tester.widget<TextField>(passwordField).controller?.text,
      'copied-password',
    );
    expect(find.byTooltip('Скрыть пароль'), findsOneWidget);
    await tester.enterText(passwordField, '');

    const hasGoogleConfiguration =
        String.fromEnvironment('MOBILE_CLERK_PUBLISHABLE_KEY') != '' &&
            String.fromEnvironment('MOBILE_GOOGLE_SERVER_CLIENT_ID') != '';
    expect(
      find.text('Вход через Google не настроен для этой сборки.'),
      hasGoogleConfiguration ? findsNothing : findsOneWidget,
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

    expect(find.text('Boom Bala'), findsOneWidget);
    expect(find.text('Вход'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
  });
}
