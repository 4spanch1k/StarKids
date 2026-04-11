import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/app/di/service_registry.dart';
import 'package:star_kids_mobile/app/theme/app_theme.dart';
import 'package:star_kids_mobile/features/branches/data/branch_seed_data.dart';
import 'package:star_kids_mobile/features/home/presentation/pages/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServiceRegistry.selectedBranchController.selectBranch(
      defaultBranchId,
      selectedBranch: getBranchById(defaultBranchId),
    );
  });

  testWidgets(
    'пункт Билеты открывает flow покупки и меняет количество билетов',
    (tester) async {
      await _pumpHomePage(tester);

      expect(find.text('Билеты'), findsOneWidget);

      await tester.tap(find.text('Билеты'));
      await tester.pumpAndSettle();

      expect(find.text('Мои билеты'), findsOneWidget);
      expect(find.text('Купить входной билет'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('buy-ticket-action')));
      await tester.pumpAndSettle();

      expect(find.text('Шаг 1 из 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('ticket-branch-select')), findsOneWidget);
      expect(find.byKey(const ValueKey('ticket-day-select')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ticket-day-select')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('selection-item-0')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();

      expect(find.text('Документ обязателен'), findsOneWidget);
      expect(find.text('Детям 0–1 лет — бесплатно'), findsOneWidget);
      expect(find.text('Имениннику в день рождения — бесплатно'), findsOneWidget);
      expect(find.text('Особенным детям — бесплатно'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ticket-count-kids_1_3')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('ticket-increase-kids_1_3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ticket-increase-kids_1_3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ticket-decrease-kids_1_3')));
      await tester.pump();

      final kidsOneToThreeCounter = tester.widget<Text>(
        find.byKey(const ValueKey('ticket-count-kids_1_3')),
      );
      expect(kidsOneToThreeCounter.data, '1');

      final decreaseFourToFifteenButton = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(const ValueKey('ticket-decrease-kids_4_15')),
          matching: find.byType(IconButton),
        ),
      );
      expect(decreaseFourToFifteenButton.onPressed, isNull);
      final kidsFourToFifteenCounter = tester.widget<Text>(
        find.byKey(const ValueKey('ticket-count-kids_4_15')),
      );
      expect(kidsFourToFifteenCounter.data, '0');

      await tester.tap(find.text('Оплатить'));
      await tester.pumpAndSettle();

      expect(
        find.text('Оплата будет подключена на следующем этапе.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Мои билеты открывают честный placeholder', (tester) async {
    await _pumpHomePage(tester);

    await tester.tap(find.text('Билеты'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('my-tickets-action')));
    await tester.pumpAndSettle();

    expect(find.text('Ваши билеты появятся здесь'), findsOneWidget);
  });
}

Future<void> _pumpHomePage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomePage(),
    ),
  );
  await tester.pump();
}
