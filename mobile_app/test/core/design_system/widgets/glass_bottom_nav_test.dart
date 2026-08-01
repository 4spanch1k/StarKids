import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/core/design_system/widgets/glass_bottom_nav.dart';

import '../../../helpers/test_app_harness.dart';

void main() {
  testWidgets('navigation labels fit a narrow mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(343, 631);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          bottomNavigationBar: GlassBottomNav(
            value: 'home',
            onChanged: (_) {},
            items: const [
              GlassNavItem(
                id: 'home',
                icon: Icons.home_outlined,
                label: 'Главная',
              ),
              GlassNavItem(
                id: 'birthdays',
                icon: Icons.cake_outlined,
                label: 'Дни рождения',
              ),
              GlassNavItem(
                id: 'promotions',
                icon: Icons.local_offer_outlined,
                label: 'Акции',
              ),
              GlassNavItem(
                id: 'tickets',
                icon: Icons.confirmation_num_outlined,
                label: 'Билеты',
              ),
              GlassNavItem(
                id: 'profile',
                icon: Icons.person_outline,
                label: 'Профиль',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Дни рождения'), findsOneWidget);
  });
}
