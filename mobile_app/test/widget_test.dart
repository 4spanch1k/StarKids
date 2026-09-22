import 'dart:async';

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

  testWidgets('unauthenticated app opens phone OTP auth gate', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const StarKidsApp());
    await tester.pumpAndSettle();

    expect(find.text('Boom Bala'), findsOneWidget);
    expect(find.text('Номер телефона'), findsOneWidget);
    expect(find.text('Получить код'), findsOneWidget);
    expect(find.text('Продолжить с Google'), findsOneWidget);

    const hasGoogleConfiguration =
        String.fromEnvironment('MOBILE_CLERK_PUBLISHABLE_KEY') != '' &&
            String.fromEnvironment('MOBILE_GOOGLE_SERVER_CLIENT_ID') != '';
    expect(
      find.text('Вход через Google не настроен для этой сборки.'),
      hasGoogleConfiguration ? findsNothing : findsOneWidget,
    );

    await tester.tap(find.text('Получить код'));
    await tester.pumpAndSettle();

    expect(find.text('Введите номер телефона.'), findsOneWidget);
  });

  testWidgets('bootstrap shell renders app while initialization is pending', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final initialization = Completer<void>();
    await tester.pumpWidget(
      StarKidsBootstrapApp(initialize: () => initialization.future),
    );
    await tester.pump();

    expect(find.text('Boom Bala'), findsOneWidget);
    expect(find.text('Номер телефона'), findsOneWidget);

    initialization.complete();
    await tester.pumpAndSettle();
  });
}
