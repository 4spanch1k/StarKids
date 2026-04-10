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

  testWidgets(
    'renders curated Al-Farabi prices, menu and birthday packages on a narrow screen',
    (
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
      expect(find.textContaining('от 4 500'), findsNothing);
      expect(find.textContaining('от 5 500'), findsNothing);
      expect(find.textContaining('от 4 000'), findsNothing);
      expect(find.textContaining('от 5 000'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Меню'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Меню'), findsOneWidget);
      expect(find.text('Меню кафе'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('MAGIC PARTY'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('MAGIC PARTY'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('STAR PARTY'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('STAR PARTY'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('WOW PARTY'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('WOW PARTY'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
