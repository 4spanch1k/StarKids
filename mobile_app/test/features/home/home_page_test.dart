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
import 'package:star_kids_mobile/features/loyalty/domain/loyalty_account.dart';
import 'package:star_kids_mobile/features/loyalty/domain/loyalty_repository.dart';
import 'package:star_kids_mobile/features/loyalty/domain/loyalty_transaction.dart';
import 'package:star_kids_mobile/features/loyalty/presentation/controllers/loyalty_controller.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_item.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_repository.dart';
import 'package:star_kids_mobile/features/request_history/presentation/controllers/request_history_controller.dart';
import 'package:star_kids_mobile/features/requests/domain/request_status.dart';
import 'package:star_kids_mobile/features/requests/domain/request_type.dart';
import 'package:star_kids_mobile/features/tickets/domain/issued_ticket.dart';
import 'package:star_kids_mobile/features/tickets/domain/issued_ticket_repository.dart';
import 'package:star_kids_mobile/features/visits/domain/current_visit.dart';
import 'package:star_kids_mobile/features/visits/domain/current_visit_repository.dart';

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

  testWidgets('checked-in state wins over ticket purchase content', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: [_ticket(id: 'ticket-1')],
      childrenController: children,
      currentVisitRepository: _FakeCurrentVisitRepository(
        currentVisit: CurrentVisit(
          visitId: 'visit-1',
          branchId: defaultBranchId,
          branchName: 'Boom Bala Алматы',
          status: 'active',
          startedAt: DateTime(2026, 9, 1, 12, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-primary-checked-in')),
      findsOneWidget,
    );
    expect(find.text('Вы сейчас в Boom Bala'), findsOneWidget);
    expect(find.text('Визит активен'), findsOneWidget);
    expect(find.text('Купить ещё билет'), findsNothing);
    children.dispose();
  });

  testWidgets('real upcoming ticket is the first operational block', (
    tester,
  ) async {
    final ticket = _ticket(id: 'ticket-1');
    final children = _childrenController([
      Child(
        id: 'child-1',
        name: 'Алиса',
        birthDate: DateTime(2020, 1, 1),
        gender: ChildGender.female,
      ),
    ]);

    await _pumpHome(tester, tickets: [ticket], childrenController: children);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-upcoming-ticket')), findsOneWidget);
    expect(find.text('Ваш ближайший визит'), findsOneWidget);
    expect(find.text('Детский билет'), findsOneWidget);
    expect(find.text('BB-0000000001'), findsOneWidget);
    expect(find.text('Boom Bala Алматы'), findsOneWidget);
    expect(find.text('05.09.2026'), findsOneWidget);
    expect(find.text('Почему Boom Bala'), findsNothing);

    children.dispose();
  });

  testWidgets('used tickets are excluded and purchase CTA remains', (
    tester,
  ) async {
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

  testWidgets('past issued ticket is skipped in favor of future ticket', (
    tester,
  ) async {
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

  testWidgets('only past issued tickets show the purchase empty state', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: [_ticket(id: 'ticket-past', visitDate: DateTime(2026, 8, 31))],
      childrenController: children,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-no-tickets')), findsOneWidget);
    expect(find.text('Ваш ближайший визит'), findsNothing);
    children.dispose();
  });

  testWidgets('today issued ticket is upcoming', (tester) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: [_ticket(id: 'ticket-today', visitDate: DateTime(2026, 9, 1))],
      childrenController: children,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-upcoming-ticket')), findsOneWidget);
    children.dispose();
  });

  testWidgets('issued ticket without visit date is not upcoming', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: [_ticket(id: 'ticket-open', noVisitDate: true)],
      childrenController: children,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-no-tickets')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-upcoming-ticket')), findsNothing);
    children.dispose();
  });

  testWidgets('same-date tickets are represented without losing quantity', (
    tester,
  ) async {
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

  testWidgets('children failure does not hide ticket and birthday blocks', (
    tester,
  ) async {
    final children = _childrenControllerFailure();

    await _pumpHome(
      tester,
      tickets: [_ticket(id: 'ticket-1')],
      childrenController: children,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-upcoming-ticket')), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-children-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-birthday-sales')), findsOneWidget);
    expect(find.text('День рождения в Boom Bala'), findsOneWidget);

    children.dispose();
  });

  testWidgets('nearby birthday is a sales block, not the primary state', (
    tester,
  ) async {
    final children = _childrenController([
      Child(
        id: 'child-1',
        name: 'Алия',
        birthDate: DateTime(2020, 9, 20),
        gender: ChildGender.female,
      ),
    ]);
    await _pumpHome(tester, tickets: const [], childrenController: children);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-primary-birthday')), findsNothing);
    expect(find.byKey(const ValueKey('home-birthday-sales')), findsOneWidget);
    expect(find.text('Алия скоро 6 лет'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-no-tickets')), findsOneWidget);
    children.dispose();
  });

  testWidgets('real children are rendered without fabricated counts', (
    tester,
  ) async {
    final children = _childrenController([
      Child(
        id: 'child-1',
        name: 'Алия',
        birthDate: DateTime(2020, 1, 1),
        gender: ChildGender.female,
      ),
      Child(
        id: 'child-2',
        name: 'Мирас',
        birthDate: DateTime(2017, 4, 1),
        gender: ChildGender.male,
      ),
    ]);
    await _pumpHome(tester, tickets: const [], childrenController: children);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-children-success')), findsOneWidget);
    expect(find.text('Алия, Мирас'), findsOneWidget);
    expect(find.textContaining('2 ребёнка'), findsNothing);
    children.dispose();
  });

  testWidgets('loyalty success is compact and visible after primary state', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      loyaltyController: _loyaltyController(
        const Success<LoyaltyAccount>(
          LoyaltyAccount(
            balance: 1250,
            reservedBalance: 0,
            availableBalance: 1250,
            lifetimeEarned: 1250,
            lifetimeSpent: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-loyalty-summary')), findsOneWidget);
    expect(find.text('1 250 доступно'), findsOneWidget);
    children.dispose();
  });

  testWidgets('loyalty error keeps purchase hero usable', (tester) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      loyaltyController: _loyaltyController(
        const Failure<LoyaltyAccount>('Бонусы недоступны'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-no-tickets')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-loyalty-error')), findsOneWidget);
    expect(find.text('Купить билет'), findsOneWidget);
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

  testWidgets('active birthday lead is shown with parent-facing status', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      requests: [
        _request(
          status: RequestStatus.newRequest,
          requestedDate: DateTime(2026, 9, 20),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-active-birthday-lead')),
      findsOneWidget,
    );
    expect(find.text('Заявка на праздник'), findsOneWidget);
    expect(find.text('Заявка отправлена'), findsOneWidget);
    expect(find.text('Алина • 20 сентября'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-birthday-sales')), findsNothing);

    children.dispose();
  });

  testWidgets('terminal birthday leads are hidden', (tester) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      requests: [_request(status: RequestStatus.cancelled)],
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-active-birthday-lead')),
      findsNothing,
    );
    children.dispose();
  });

  testWidgets('contacted lead uses active status copy', (tester) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      requests: [
        _request(
          status: RequestStatus.contacted,
          requestedDate: DateTime(2026, 9, 20),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Менеджер связался'), findsOneWidget);
    children.dispose();
  });

  testWidgets('qualified and booked leads remain active on Home', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      requests: [
        _request(
          status: RequestStatus.qualified,
          requestedDate: DateTime(2026, 9, 20),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('home-active-birthday-lead')),
      findsOneWidget,
    );
    expect(find.text('Детали уточняются'), findsOneWidget);
    children.dispose();
  });

  testWidgets('completed lead is terminal and hidden from Home', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      requests: [_request(status: RequestStatus.completed)],
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('home-active-birthday-lead')),
      findsNothing,
    );
    children.dispose();
  });

  testWidgets('confirmed lead remains visible with confirmation copy', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await tester.pumpWidget(
      buildTestApp(
        child: HomePage(
          issuedTicketRepository: _FakeIssuedTicketRepository(const []),
          childrenController: children,
          newsController: NewsFeedController(
            repository: const _EmptyNewsRepository(),
          ),
          nowProvider: _fixedToday,
          requestHistoryController: _requestHistoryController([
            _request(
              status: RequestStatus.confirmed,
              requestedDate: DateTime(2026, 9, 20),
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Праздник подтверждён'), findsOneWidget);
    children.dispose();
  });

  testWidgets('request history failure does not block Home', (tester) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      requestHistoryController: RequestHistoryController(
        repository: _FakeRequestHistoryRepository.failure(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Планируете посещение?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-active-birthday-lead')),
      findsNothing,
    );
    children.dispose();
  });

  testWidgets('returning family shows visit count and last visit', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      currentVisitRepository: _FakeCurrentVisitRepository(
        history: VisitHistory(
          visitCount: 3,
          firstVisitAt: DateTime(2026, 1, 10, 12),
          lastVisitAt: DateTime(2026, 9, 5, 15),
          items: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('С возвращением'), findsOneWidget);
    expect(find.text('Вы были у нас 3 раза'), findsOneWidget);
    expect(find.text('Последний визит — 5 сентября'), findsOneWidget);
    expect(find.text('Купить билет'), findsOneWidget);
    children.dispose();
  });

  testWidgets('returning family renders a singular visit count', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      currentVisitRepository: _FakeCurrentVisitRepository(
        history: const VisitHistory(
          visitCount: 1,
          firstVisitAt: null,
          lastVisitAt: null,
          items: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вы были у нас 1 раз'), findsOneWidget);
    children.dispose();
  });

  testWidgets('visit history failure does not invent returning context', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      currentVisitRepository: _FakeCurrentVisitRepository(failHistory: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('С возвращением'), findsNothing);
    expect(find.text('Планируете посещение?'), findsOneWidget);
    expect(find.text('Купить билет'), findsOneWidget);
    children.dispose();
  });

  testWidgets('nearest active birthday lead wins deterministically', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      requests: [
        _request(
          id: 'later',
          childName: 'Позже',
          requestedDate: DateTime(2026, 10, 1),
        ),
        _request(
          id: 'nearest',
          childName: 'Алина',
          requestedDate: DateTime(2026, 9, 20),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Алина • 20 сентября'), findsOneWidget);
    expect(find.text('Позже • 1 октября'), findsNothing);
    children.dispose();
  });

  testWidgets('legacy nullable birthday lead does not crash Home', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      requests: [_request(requestedDate: null, childName: null, package: null)],
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-active-birthday-lead')),
      findsOneWidget,
    );
    expect(find.text('Заявка на праздник'), findsOneWidget);
    expect(find.text('null'), findsNothing);
    children.dispose();
  });

  testWidgets('lead CTA opens the existing request history route', (
    tester,
  ) async {
    final children = _childrenController(const []);
    await _pumpHome(
      tester,
      tickets: const [],
      childrenController: children,
      requests: [_request()],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открыть заявку'));
    await tester.pumpAndSettle();

    expect(find.text('Мои заявки'), findsOneWidget);
    children.dispose();
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<IssuedTicket> tickets,
  required ChildrenController childrenController,
  DateTime Function()? nowProvider,
  List<RequestHistoryItem> requests = const [],
  RequestHistoryController? requestHistoryController,
  CurrentVisitRepository? currentVisitRepository,
  LoyaltyController? loyaltyController,
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
        requestHistoryController:
            requestHistoryController ?? _requestHistoryController(requests),
        currentVisitRepository: currentVisitRepository,
        loyaltyController: loyaltyController,
      ),
    ),
  );
  await tester.pump();
}

RequestHistoryController _requestHistoryController(
  List<RequestHistoryItem> items,
) {
  return RequestHistoryController(
    repository: _FakeRequestHistoryRepository(items),
  );
}

RequestHistoryItem _request({
  String id = 'request-1',
  RequestStatus status = RequestStatus.newRequest,
  String? childName = 'Алина',
  DateTime? requestedDate,
  RequestHistoryPackageSummary? package = const RequestHistoryPackageSummary(
    id: 'package-1',
    name: 'Праздник Spark',
  ),
}) {
  return RequestHistoryItem(
    id: id,
    type: RequestType.birthdayRequest,
    status: status,
    createdAt: DateTime(2026, 9, 1, 10),
    requestedDate: requestedDate,
    childName: childName,
    package: package,
  );
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
    repository: _FakeChildrenRepository(Success(children)),
  );
}

ChildrenController _childrenControllerFailure() {
  return ChildrenController(
    repository: _FakeChildrenRepository(
      const Failure<List<Child>>('Не удалось загрузить детей.'),
    ),
  );
}

LoyaltyController _loyaltyController(Result<LoyaltyAccount> result) {
  return LoyaltyController(repository: _FakeLoyaltyRepository(result));
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

class _FakeRequestHistoryRepository implements RequestHistoryRepository {
  _FakeRequestHistoryRepository(this.items) : _failure = false;

  _FakeRequestHistoryRepository.failure()
      : items = const [],
        _failure = true;

  final List<RequestHistoryItem> items;
  final bool _failure;

  @override
  Future<RequestHistoryFetchResult> fetchMyRequests() async {
    if (_failure) {
      return const RequestHistoryFetchFailure('Не удалось загрузить заявки.');
    }
    return RequestHistoryFetchSuccess(items: items, total: items.length);
  }
}

class _FakeLoyaltyRepository implements LoyaltyRepository {
  _FakeLoyaltyRepository(this.accountResult);

  final Result<LoyaltyAccount> accountResult;

  @override
  Future<Result<LoyaltyAccount>> fetchAccount() async => accountResult;

  @override
  Future<Result<List<LoyaltyTransaction>>> fetchTransactions({
    int limit = 20,
    int offset = 0,
  }) async =>
      const Success<List<LoyaltyTransaction>>([]);
}

class _FakeCurrentVisitRepository implements CurrentVisitRepository {
  _FakeCurrentVisitRepository({
    this.history,
    this.currentVisit,
    this.failHistory = false,
  });

  final VisitHistory? history;
  final CurrentVisit? currentVisit;
  final bool failHistory;

  @override
  Future<CurrentVisit?> getCurrentVisit() async => currentVisit;

  @override
  Future<VisitHistory> getVisitHistory() async {
    if (failHistory) {
      throw StateError('Visit history unavailable.');
    }
    return history ??
        const VisitHistory(
          visitCount: 0,
          firstVisitAt: null,
          lastVisitAt: null,
          items: [],
        );
  }
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
