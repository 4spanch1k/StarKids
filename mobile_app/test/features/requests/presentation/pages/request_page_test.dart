import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/features/requests/domain/request_type.dart';
import 'package:star_kids_mobile/features/requests/presentation/models/request_page_args.dart';
import 'package:star_kids_mobile/features/requests/presentation/pages/request_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders contact request form when contact type is selected',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RequestPage(
          args: RequestPageArgs(initialType: RequestType.contact),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Связь с менеджером'), findsWidgets);
    expect(find.text('Оставьте запрос на обратную связь'), findsOneWidget);
    expect(find.text('Отправить запрос'), findsOneWidget);
    expect(find.text('Пакет праздника'), findsNothing);
  });

  testWidgets('switches from birthday request to contact request in one flow',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RequestPage(
          args: RequestPageArgs(
            initialType: RequestType.birthdayRequest,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Пакет праздника'), findsOneWidget);
    expect(find.text('Отправить заявку'), findsOneWidget);

    await tester.tap(find.text('Связь с менеджером').last);
    await tester.pumpAndSettle();

    expect(find.text('Пакет праздника'), findsNothing);
    expect(find.text('Оставьте запрос на обратную связь'), findsOneWidget);
    expect(find.text('Отправить запрос'), findsOneWidget);
  });
}
