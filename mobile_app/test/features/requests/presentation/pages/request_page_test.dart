import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/features/requests/domain/request_type.dart';
import 'package:star_kids_mobile/features/requests/presentation/models/request_page_args.dart';
import 'package:star_kids_mobile/features/requests/presentation/pages/request_page.dart';

import '../../../../helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders contact request form when contact type is selected',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: const RequestPage(
          args: RequestPageArgs(initialType: RequestType.contact),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Менеджеру'), findsWidgets);
    expect(find.textContaining('Короткий запрос'), findsOneWidget);
    expect(find.textContaining('без переписок.'), findsOneWidget);
    expect(find.text('Отправить запрос'), findsOneWidget);
    expect(find.text('Пакет праздника'), findsNothing);
  });

  testWidgets('birthday request form does not render contact fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: const RequestPage(
          args: RequestPageArgs(
            initialType: RequestType.birthdayRequest,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Пакет праздника'), findsOneWidget);
    expect(find.text('Отправить заявку'), findsOneWidget);

    expect(find.textContaining('Короткий запрос'), findsNothing);
    expect(find.text('Отправить запрос'), findsNothing);
  });

  testWidgets('shows contact context and prefilled message when provided',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: const RequestPage(
          args: RequestPageArgs(
            initialType: RequestType.contact,
            initialContactContextLabel: 'Филиал: Star Kids Main',
            initialContactMessage:
                'Интересует филиал Star Kids Main. Нужна помощь по маршруту.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Филиал: Star Kids Main'), findsOneWidget);
    expect(
      find.textContaining('Запрос уйдёт менеджеру по выбранному филиалу'),
      findsOneWidget,
    );
  });
}
