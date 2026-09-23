import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/features/tickets/domain/issued_ticket.dart';
import 'package:star_kids_mobile/features/tickets/domain/issued_ticket_repository.dart';
import 'package:star_kids_mobile/features/tickets/presentation/pages/ticket_detail_page.dart';
import 'package:star_kids_mobile/features/tickets/presentation/pages/tickets_page.dart';
import 'package:star_kids_mobile/features/tickets/presentation/models/tickets_page_args.dart';
import 'package:star_kids_mobile/features/passes/domain/pass.dart';
import 'package:star_kids_mobile/features/passes/domain/pass_repository.dart';
import 'package:star_kids_mobile/core/utils/result.dart';

import '../../helpers/test_app_harness.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('empty IssuedTicket response shows empty state and buy CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: TicketsPage(repository: _FakeIssuedTicketRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('У вас пока нет билетов'), findsOneWidget);
    expect(find.text('Купить билет'), findsOneWidget);
  });

  testWidgets('each issued ticket is rendered as an individual card', (
    tester,
  ) async {
    final tickets = [
      _ticket('1', 'BB-0001', 'Детский билет', DateTime(2026, 9, 2)),
      _ticket('2', 'BB-0002', 'Детский билет', DateTime(2026, 9, 2)),
      _ticket('3', 'BB-0003', 'Взрослый билет', DateTime(2026, 9, 5)),
    ];
    await tester.pumpWidget(
      buildTestApp(
        child: TicketsPage(
          repository: _FakeIssuedTicketRepository(tickets: tickets),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BB-0001'), findsOneWidget);
    expect(find.text('BB-0002'), findsOneWidget);
    expect(find.text('BB-0003'), findsOneWidget);
    expect(find.text('Детский билет'), findsNWidgets(2));
    expect(find.text('Взрослый билет'), findsOneWidget);
    expect(find.text('Действует'), findsNWidgets(3));
  });

  testWidgets('ticket card opens detail loaded from IssuedTicket endpoint', (
    tester,
  ) async {
    final ticket =
        _ticket('42', 'BB-0042', 'Семейный билет', DateTime(2026, 9, 8));
    final repository = _FakeIssuedTicketRepository(tickets: [ticket]);
    await tester
        .pumpWidget(buildTestApp(child: TicketsPage(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Открыть билет'));
    await tester.pumpAndSettle();

    expect(find.text('BB-0042'), findsOneWidget);
    expect(find.text('Семейный билет'), findsOneWidget);
    expect(repository.requestedTicketId, '42');
  });

  testWidgets('detail page requests the selected ticket and renders fields', (
    tester,
  ) async {
    final ticket =
        _ticket('7', 'BB-0007', 'Детский билет', DateTime(2026, 9, 10));
    final repository = _FakeIssuedTicketRepository(tickets: [ticket]);
    await tester.pumpWidget(
      buildTestApp(
        child: TicketDetailPage(ticketId: '7', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BB-0007'), findsOneWidget);
    expect(find.text('Boom Bala — Main'), findsOneWidget);
    expect(find.text('3700 тг'), findsOneWidget);
    expect(repository.requestedTicketId, '7');
  });

  testWidgets(
      'API failure exposes retry and does not fall back to seed tickets', (
    tester,
  ) async {
    final repository = _FakeIssuedTicketRepository(failFirst: true);
    await tester
        .pumpWidget(buildTestApp(child: TicketsPage(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить билеты'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('У вас пока нет билетов'), findsOneWidget);
  });

  testWidgets('issued ticket detail renders backend QR payload',
      (tester) async {
    final ticket =
        _ticket('8', 'BB-0008', 'Детский билет', DateTime(2026, 9, 10));
    final repository = _FakeIssuedTicketRepository(tickets: [ticket]);
    await tester.pumpWidget(
      buildTestApp(
        child: TicketDetailPage(ticketId: '8', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(repository.requestedQrTicketId, '8');
    expect(find.text('Покажите QR сотруднику на входе.'), findsOneWidget);
    expect(find.text('BB-0008'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('ticket_qr_payload:8'),
      'bb_ticket:v1:8:backend-signature',
    );
  });

  testWidgets('QR error keeps ticket data visible and exposes retry',
      (tester) async {
    final ticket =
        _ticket('9', 'BB-0009', 'Детский билет', DateTime(2026, 9, 11));
    final repository = _FakeIssuedTicketRepository(
      tickets: [ticket],
      failQr: true,
    );
    await tester.pumpWidget(
      buildTestApp(
        child: TicketDetailPage(ticketId: '9', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BB-0009'), findsOneWidget);
    expect(find.text('Не удалось загрузить QR-код. Попробуйте еще раз.'),
        findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('cached QR remains visible when the QR request is offline',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'ticket_qr_payload:10': 'bb_ticket:v1:10:cached-signature',
    });
    final ticket =
        _ticket('10', 'BB-0010', 'Детский билет', DateTime(2026, 9, 12));
    final repository = _FakeIssuedTicketRepository(
      tickets: [ticket],
      failQr: true,
    );

    await tester.pumpWidget(
      buildTestApp(
        child: TicketDetailPage(ticketId: '10', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Не удалось загрузить QR-код. Попробуйте еще раз.'),
        findsNothing);
  });

  testWidgets('terminal ticket status removes cached QR', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ticket_qr_payload:11': 'bb_ticket:v1:11:cached-signature',
    });
    final ticket = _ticket(
      '11',
      'BB-0011',
      'Детский билет',
      DateTime(2026, 9, 12),
      status: 'used',
    );

    await tester.pumpWidget(
      buildTestApp(
        child: TicketDetailPage(
          ticketId: '11',
          initialTicket: ticket,
          repository: _FakeIssuedTicketRepository(tickets: [ticket]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('ticket_qr_payload:11'), isNull);
  });

  testWidgets('plan API error is distinct from an empty plan catalog', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: TicketsPage(
          initialSection: TicketsSection.passes,
          repository: _FakeIssuedTicketRepository(),
          passRepository: _FakePassRepository(planError: 'Планы недоступны.'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить планы'), findsOneWidget);
    expect(find.text('Планы недоступны.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.text('Для выбранного филиала сейчас нет доступных планов.'),
        findsNothing);
  });
}

IssuedTicket _ticket(String id, String number, String title, DateTime visitDate,
    {String status = 'issued'}) {
  return IssuedTicket(
    ticketId: id,
    ticketNumber: number,
    ticketItemId: 'item-$id',
    title: title,
    branchId: 'main',
    branchName: 'Boom Bala — Main',
    visitDate: visitDate,
    priceTenge: 3700,
    status: status,
    issuedAt: DateTime(2026, 8, 31),
  );
}

class _FakeIssuedTicketRepository implements IssuedTicketRepository {
  _FakeIssuedTicketRepository(
      {this.tickets = const [], this.failFirst = false, this.failQr = false});

  final List<IssuedTicket> tickets;
  final bool failFirst;
  final bool failQr;
  String? requestedTicketId;
  String? requestedQrTicketId;
  var _listCalls = 0;

  @override
  Future<List<IssuedTicket>> listIssuedTickets() async {
    _listCalls += 1;
    if (failFirst && _listCalls == 1) {
      throw StateError('offline');
    }
    return List<IssuedTicket>.of(tickets);
  }

  @override
  Future<IssuedTicket> getIssuedTicket(String ticketId) async {
    requestedTicketId = ticketId;
    return tickets.firstWhere((ticket) => ticket.ticketId == ticketId);
  }

  @override
  Future<String> getIssuedTicketQrPayload(String ticketId) async {
    requestedQrTicketId = ticketId;
    if (failQr) throw StateError('QR unavailable');
    return 'bb_ticket:v1:$ticketId:backend-signature';
  }
}

class _FakePassRepository implements PassRepository {
  _FakePassRepository({this.planError});

  final String? planError;

  @override
  Future<Result<List<PassPlan>>> listPlans({String? branchId}) async {
    if (planError != null) return Failure<List<PassPlan>>(planError!);
    return const Success<List<PassPlan>>([]);
  }

  @override
  Future<Result<List<CustomerPass>>> listPasses() async =>
      const Success<List<CustomerPass>>([]);

  @override
  Future<Result<CustomerPass>> getPass(String passId) =>
      throw UnimplementedError();

  @override
  Future<Result<String>> getPassQrPayload(String passId) =>
      throw UnimplementedError();

  @override
  Future<Result<PassQuote>> quote({
    required String childId,
    required String passPlanId,
    required String branchId,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<PassPaymentStart>> startPayment({
    required String childId,
    required String passPlanId,
    required String branchId,
    required String idempotencyKey,
  }) =>
      throw UnimplementedError();
}
