import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/app/app.dart';
import 'package:star_kids_mobile/app/router/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('commercial surfaces are reachable from home', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const StarKidsApp());
    expect(find.text('Star Kids Shymkent'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Star Kids Al-Farabi'));
    await tester.tap(find.text('Star Kids Al-Farabi'));
    await tester.pumpAndSettle();

    final navigator = Navigator.of(
      tester.element(find.byType(Scaffold).first),
    );

    navigator.pushNamed(AppRoutes.promotions);
    await tester.pumpAndSettle();
    expect(find.text('Акции'), findsWidgets);

    navigator.pop();
    await tester.pumpAndSettle();

    navigator.pushNamed(AppRoutes.pricesRules);
    await tester.pumpAndSettle();
    expect(find.text('Цены и правила'), findsWidgets);

    navigator.pop();
    await tester.pumpAndSettle();

    navigator.pushNamed(AppRoutes.contacts);
    await tester.pumpAndSettle();
    expect(find.text('Контакты и маршрут'), findsOneWidget);

    navigator.pop();
    await tester.pumpAndSettle();

    navigator.pushNamed(AppRoutes.profile);
    await tester.pumpAndSettle();
    expect(find.text('Войдите по номеру телефона'), findsOneWidget);
  });
}
