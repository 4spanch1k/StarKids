import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/core/design_system/widgets/sk_button.dart';
import 'package:star_kids_mobile/core/design_system/widgets/sk_hero.dart';

import '../../../helpers/test_app_harness.dart';

void main() {
  testWidgets('compact hero fits a narrow mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(343, 631);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SkHero(
              imageUrl: 'assets/images/home_hero.jpg',
              chip: 'Любят дети · доверяют родители',
              title: 'Семейный отдых\nи яркие дни рождения.',
              italicText: 'яркие',
              meta: '3000 м² · 11:00 — 23:00',
              action: SkButton(
                label: 'Организовать день рождения',
                block: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Организовать день рождения'), findsOneWidget);
  });
}
