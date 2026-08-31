import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/features/tickets/domain/issued_ticket.dart';
import 'package:star_kids_mobile/features/tickets/domain/issued_ticket_repository.dart';
import 'package:star_kids_mobile/features/tickets/presentation/pages/ticket_detail_page.dart';
import 'package:star_kids_mobile/features/tickets/presentation/pages/tickets_page.dart';

import '../../helpers/test_app_harness.dart';

void main() {
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
}

IssuedTicket _ticket(
  String id,
  String number,
  String title,
  DateTime visitDate,
) {
  return IssuedTicket(
    ticketId: id,
    ticketNumber: number,
    ticketItemId: 'item-$id',
    title: title,
    branchId: 'main',
    branchName: 'Boom Bala — Main',
    visitDate: visitDate,
    priceTenge: 3700,
    status: 'issued',
    issuedAt: DateTime(2026, 8, 31),
  );
}

class _FakeIssuedTicketRepository implements IssuedTicketRepository {
  _FakeIssuedTicketRepository(
      {this.tickets = const [], this.failFirst = false});

  final List<IssuedTicket> tickets;
  final bool failFirst;
  String? requestedTicketId;
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
}
