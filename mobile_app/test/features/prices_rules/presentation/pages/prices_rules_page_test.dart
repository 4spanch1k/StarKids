import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/app/theme/app_theme.dart';
import 'package:star_kids_mobile/features/prices_rules/presentation/pages/prices_rules_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders curated Al-Farabi prices and menu on a narrow screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const PricesRulesPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ТРЦ «Аль-Фараби»'), findsOneWidget);
    expect(find.text('2700 тг'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Меню'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Меню'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Чай'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Чай'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
