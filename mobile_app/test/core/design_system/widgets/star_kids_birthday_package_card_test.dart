import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/core/design_system/widgets/star_kids_birthday_package_card.dart';

import '../../../helpers/test_app_harness.dart';

void main() {
  testWidgets('compact birthday package fits the mobile carousel', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              height: 356,
              child: StarKidsBirthdayPackageCard(
                title: 'Spark Party with a long title',
                priceLabel: 'от 55 000 ₸',
                guestLabel: 'до 10 детей',
                description:
                    'Быстрый и яркий формат для семейного праздника без сложной организации.',
                highlights: const [
                  'Игровая зона',
                  'Аниматор',
                  'Праздничное меню',
                ],
                imagePath: '',
                compact: true,
                onActionTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('от 55 000 ₸'), findsOneWidget);
    expect(find.text('Оставить заявку'), findsOneWidget);
  });
}
