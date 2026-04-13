import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    expect(find.text('Вход в приложение'), findsOneWidget);
    expect(find.text('Вход'), findsWidgets);
    expect(find.text('Регистрация'), findsOneWidget);
    expect(find.text('Электронная почта'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);

    await tester.tap(find.text('Войти').last);
    await tester.pumpAndSettle();

    expect(find.text('Введите email.'), findsOneWidget);
    expect(find.text('Введите пароль.'), findsOneWidget);
  });
}
