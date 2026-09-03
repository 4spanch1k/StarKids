import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/app/di/service_registry.dart';
import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/branches/data/branch_seed_data.dart';
import 'package:star_kids_mobile/features/children/domain/child.dart';
import 'package:star_kids_mobile/features/children/domain/children_repository.dart';
import 'package:star_kids_mobile/features/children/presentation/controllers/children_controller.dart';
import 'package:star_kids_mobile/features/home/presentation/pages/home_page.dart';
import 'package:star_kids_mobile/features/news/domain/news_item.dart';
import 'package:star_kids_mobile/features/news/domain/news_repository.dart';
import 'package:star_kids_mobile/features/news/presentation/controllers/news_feed_controller.dart';
import 'package:star_kids_mobile/features/tickets/domain/issued_ticket.dart';
import 'package:star_kids_mobile/features/tickets/domain/issued_ticket_repository.dart';

import '../../helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    NewsFeedController.clearCache();
    SharedPreferences.setMockInitialValues({});
    await ServiceRegistry.selectedBranchController.selectBranch(
      defaultBranchId,
      selectedBranch: getBranchById(defaultBranchId),
    );
  });

  testWidgets('real upcoming ticket is the first operational block',
      (tester) async {
    final ticket = _ticket(id: 'ticket-1');
    final children = _childrenController(
      [
        Child(
          id: 'child-1',
          name: 'Алиса',
          birthDate: DateTime(2020, 1, 1),
          gender: ChildGender.female,
        ),
      ],
    );

    await _pumpHome(tester, tickets: [ticket], childrenController: children);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-upcoming-ticket')), findsOneWidget);
    expect(find.text('Ближайшее посещение'), findsOneWidget);
    expect(find.text('Детский билет'), findsOneWidget);
    expect(find.text('BB-0000000001'), findsOneWidget);
    expect(find.text('Boom Bala Алматы'), findsOneWidget);
    expect(find.text('05.09.2026'), findsOneWidget);
    expect(find.text('Почему Boom Bala'), findsNothing);

    children.dispose();
  });

  testWidgets('used tickets are excluded and purchase CTA remains',
      (tester) async {
    final used = _ticket(id: 'ticket-used', status: 'used');
    final children = _childrenController(const []);

    await _pumpHome(tester, tickets: [used], childrenController: children);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-no-tickets')), findsOneWidget);
    expect(find.text('Планируете посещение?'), findsOneWidget);
    expect(find.text('Купить билет'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-upcoming-ticket')), findsNothing);

    children.dispose();
  });

  testWidgets('past issued ticket is skipped in favor of future ticket',
      (tester) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: [
        _ticket(id: 'ticket-past', visitDate: DateTime(2026, 8, 31)),
        _ticket(id: 'ticket-future', number: 'BB-0000000002'),
      ],
      childrenController: children,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-upcoming-ticket')), findsOneWidget);
    expect(find.text('BB-0000000002'), findsOneWidget);
    expect(find.text('BB-0000000001'), findsNothing);
    children.dispose();
  });

  testWidgets('only past issued tickets show the purchase empty state',
      (tester) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: [
        _ticket(id: 'ticket-past', visitDate: DateTime(2026, 8, 31)),
      ],
      childrenController: children,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-no-tickets')), findsOneWidget);
    expect(find.text('Ближайшее посещение'), findsNothing);
    children.dispose();
  });

  testWidgets('today issued ticket is upcoming', (tester) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: [
        _ticket(id: 'ticket-today', visitDate: DateTime(2026, 9, 1)),
      ],
      childrenController: children,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-upcoming-ticket')), findsOneWidget);
    children.dispose();
  });

  testWidgets('issued ticket without visit date is not upcoming',
      (tester) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: [
        _ticket(id: 'ticket-open', noVisitDate: true),
      ],
      childrenController: children,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-no-tickets')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-upcoming-ticket')), findsNothing);
    children.dispose();
  });

  testWidgets('same-date tickets are represented without losing quantity',
      (tester) async {
    final tickets = [
      _ticket(id: 'ticket-1'),
      _ticket(id: 'ticket-2', number: 'BB-0000000002'),
      _ticket(id: 'ticket-3', number: 'BB-0000000003'),
    ];
    final children = _childrenController(const []);

    await _pumpHome(tester, tickets: tickets, childrenController: children);
    await tester.pumpAndSettle();

    expect(find.text('3 билета · 05.09.2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-upcoming-ticket')), findsOneWidget);

    children.dispose();
  });

  testWidgets('children failure does not hide ticket and birthday blocks',
      (tester) async {
    final children = _childrenControllerFailure();

    await _pumpHome(
      tester,
      tickets: [_ticket(id: 'ticket-1')],
      childrenController: children,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-upcoming-ticket')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-children-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-birthday-cta')), findsOneWidget);
    expect(find.text('Планируете день рождения?'), findsOneWidget);

    children.dispose();
  });

  testWidgets('ticket CTA opens the existing TicketDetailPage', (tester) async {
    final ticket = _ticket(id: 'ticket-1');
    final children = _childrenController(const []);

    await _pumpHome(tester, tickets: [ticket], childrenController: children);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открыть билет'));
    await tester.pumpAndSettle();

    expect(find.text('Готов к посещению'), findsOneWidget);
    expect(find.text('Покажите QR сотруднику на входе.'), findsOneWidget);

    children.dispose();
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<IssuedTicket> tickets,
  required ChildrenController childrenController,
  DateTime Function()? nowProvider,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    buildTestApp(
      child: HomePage(
        issuedTicketRepository: _FakeIssuedTicketRepository(tickets),
        childrenController: childrenController,
        newsController: NewsFeedController(
          repository: const _EmptyNewsRepository(),
        ),
        nowProvider: nowProvider ?? _fixedToday,
      ),
    ),
  );
  await tester.pump();
}

IssuedTicket _ticket({
  required String id,
  String? number,
  String status = 'issued',
  DateTime? visitDate,
  bool noVisitDate = false,
}) {
  return IssuedTicket(
    ticketId: id,
    ticketNumber: number ?? 'BB-0000000001',
    ticketItemId: 'kids_4_15',
    title: 'Детский билет',
    branchId: defaultBranchId,
    branchName: 'Boom Bala Алматы',
    visitDate: noVisitDate ? null : (visitDate ?? DateTime(2026, 9, 5)),
    priceTenge: 3700,
    status: status,
    issuedAt: DateTime(2026, 9, 1),
  );
}

DateTime _fixedToday() => DateTime(2026, 9, 1, 12);

ChildrenController _childrenController(List<Child> children) {
  return ChildrenController(
      repository: _FakeChildrenRepository(Success(children)));
}

ChildrenController _childrenControllerFailure() {
  return ChildrenController(
    repository: _FakeChildrenRepository(
      const Failure<List<Child>>('Не удалось загрузить детей.'),
    ),
  );
}

class _FakeIssuedTicketRepository implements IssuedTicketRepository {
  _FakeIssuedTicketRepository(this.tickets);

  final List<IssuedTicket> tickets;

  @override
  Future<List<IssuedTicket>> listIssuedTickets() async => tickets;

  @override
  Future<IssuedTicket> getIssuedTicket(String ticketId) async =>
      tickets.firstWhere((ticket) => ticket.ticketId == ticketId);

  @override
  Future<String> getIssuedTicketQrPayload(String ticketId) async =>
      'bb_ticket:v1:$ticketId:signed';
}

class _FakeChildrenRepository implements ChildrenRepository {
  _FakeChildrenRepository(this.result);

  final Result<List<Child>> result;

  @override
  Future<Result<List<Child>>> fetchChildren() async => result;

  @override
  Future<Result<Child>> createChild({
    required String name,
    required DateTime birthDate,
    required ChildGender gender,
  }) async =>
      const Failure<Child>('Not used in Home tests.');

  @override
  Future<Result<Child>> updateChild({
    required String childId,
    String? name,
    DateTime? birthDate,
    ChildGender? gender,
  }) async =>
      const Failure<Child>('Not used in Home tests.');

  @override
  Future<Result<void>> deleteChild(String childId) async =>
      const Failure<void>('Not used in Home tests.');
}

class _EmptyNewsRepository implements NewsRepository {
  const _EmptyNewsRepository();

  @override
  Future<NewsItem> getNewsDetails(String newsId) async =>
      throw StateError('No news in Home tests.');

  @override
  Future<List<NewsItem>> listNotificationHistory({
    required int limit,
    required int offset,
  }) async =>
      const [];

  @override
  Future<List<NewsItem>> listPromotedNews({
    required int limit,
    required int offset,
  }) async =>
      const [];

  @override
  Future<void> trackNewsEvent({
    required String newsId,
    required NewsEventType eventType,
  }) async {}
}
