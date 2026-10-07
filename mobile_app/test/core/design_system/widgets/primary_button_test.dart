import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/core/design_system/widgets/primary_button.dart';

import '../../../helpers/test_app_harness.dart';

void main() {
  testWidgets('secondary button does not overflow in a narrow constraint', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 140,
              child: SecondaryButton(
                label: 'Построить маршрут',
                icon: Icons.map_rounded,
                fullWidth: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Построить маршрут'), findsOneWidget);
  });
}
