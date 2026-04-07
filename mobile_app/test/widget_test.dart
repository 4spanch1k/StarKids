import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/app/app.dart';

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

    final promotionsTile = find.widgetWithText(Card, 'Акции');
    final pricesRulesTile = find.widgetWithText(Card, 'Цены и правила');
    final contactsTile = find.widgetWithText(Card, 'Контакты и карта');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    await tester.tap(promotionsTile);
    await tester.pumpAndSettle();
    expect(find.text('Акции'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(pricesRulesTile);
    await tester.pumpAndSettle();
    expect(find.text('Цены и правила'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(contactsTile);
    await tester.pumpAndSettle();
    expect(find.text('Контакты и маршрут'), findsOneWidget);
  });
}
