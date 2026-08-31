import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/app/di/service_registry.dart';
import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/branches/data/branch_seed_data.dart';
import 'package:star_kids_mobile/features/home/presentation/pages/home_page.dart';
import 'package:star_kids_mobile/features/news/domain/news_item.dart';
import 'package:star_kids_mobile/features/news/domain/news_repository.dart';
import 'package:star_kids_mobile/features/news/presentation/controllers/news_feed_controller.dart';
import 'package:star_kids_mobile/features/tickets/data/seed_ticket_config_repository.dart';
import 'package:star_kids_mobile/features/tickets/domain/branch_ticket_config.dart';
import 'package:star_kids_mobile/features/tickets/domain/ticket_purchase.dart';
import 'package:star_kids_mobile/features/tickets/domain/ticket_purchase_repository.dart';
import 'package:star_kids_mobile/features/tickets/domain/issued_ticket.dart';
import 'package:star_kids_mobile/features/tickets/domain/issued_ticket_repository.dart';

import '../../helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    NewsFeedController.clearCache();
    SharedPreferences.setMockInitialValues({});
    ServiceRegistry.ticketConfigRepository = const SeedTicketConfigRepository(
      config: BranchTicketConfig(
        branchId: defaultBranchId,
        items: [
          TicketConfigItem(
            id: 'kids_1_3',
            title: 'Детские билеты 1–3 лет',
            priceTenge: 2700,
            description: 'Документ обязателен',
            badgeLabels: [],
          ),
          TicketConfigItem(
            id: 'kids_4_15',
            title: 'Детские билеты 4–15 лет',
            priceTenge: 3700,
            description: '',
            badgeLabels: ['Бесплатно до 1 года не требуется'],
          ),
        ],
        notes: [
          'Детям 0–1 лет — бесплатно',
          'Имениннику в день рождения — бесплатно',
        ],
      ),
    );
    ServiceRegistry.ticketPurchaseRepository =
        const _FakeTicketPurchaseRepository();
    ServiceRegistry.issuedTicketRepository =
        const _FakeIssuedTicketRepository();
    ServiceRegistry.paymentUrlLauncher = (_) async => true;
    await ServiceRegistry.selectedBranchController.selectBranch(
      defaultBranchId,
      selectedBranch: getBranchById(defaultBranchId),
    );
  });

  tearDown(() {
    ServiceRegistry.resetTicketConfigRepository();
    ServiceRegistry.resetTicketPurchaseRepository();
    ServiceRegistry.resetIssuedTicketRepository();
    ServiceRegistry.resetPaymentUrlLauncher();
  });

  testWidgets('пункт Билеты открывает flow покупки и меняет количество билетов',
      (
    tester,
  ) async {
    await _pumpHomePage(tester);

    expect(find.text('Билеты'), findsOneWidget);

    await tester.tap(find.text('Билеты'));
    await tester.pumpAndSettle();

    expect(find.text('Мои билеты'), findsOneWidget);
    expect(find.text('Купить билет'), findsOneWidget);

    await tester.tap(find.text('Купить билет'));
    await tester.pumpAndSettle();

    expect(find.text('Шаг 1 из 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('ticket-branch-select')), findsOneWidget);
    expect(find.byKey(const ValueKey('ticket-day-select')), findsOneWidget);
    expect(find.text('ДОСТУПНЫЕ ТАРИФЫ'), findsOneWidget);
    expect(find.text('Детские билеты 1–3 лет'), findsOneWidget);
    expect(find.text('2 700 тг'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ticket-day-select')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('selection-item-0')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.text('Документ обязателен'), findsOneWidget);
    expect(find.text('Детям 0–1 лет — бесплатно'), findsOneWidget);
    expect(find.text('Имениннику в день рождения — бесплатно'), findsOneWidget);
    expect(find.byKey(const ValueKey('ticket-count-kids_1_3')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ticket-increase-kids_1_3')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ticket-increase-kids_1_3')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ticket-decrease-kids_1_3')));
    await tester.pump();

    final kidsOneToThreeCounter = tester.widget<Text>(
      find.byKey(const ValueKey('ticket-count-kids_1_3')),
    );
    expect(kidsOneToThreeCounter.data, '1');

    final decreaseFourToFifteenButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('ticket-decrease-kids_4_15')),
        matching: find.byType(IconButton),
      ),
    );
    expect(decreaseFourToFifteenButton.onPressed, isNull);
    final kidsFourToFifteenCounter = tester.widget<Text>(
      find.byKey(const ValueKey('ticket-count-kids_4_15')),
    );
    expect(kidsFourToFifteenCounter.data, '0');

    await tester.tap(find.text('Оплатить через Freedom Pay'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Страница оплаты открыта. После завершения вернитесь и проверьте статус.',
      ),
      findsOneWidget,
    );
    expect(find.text('Проверить оплату'), findsOneWidget);
  });

  testWidgets('Билеты открывают настоящий экран IssuedTicket', (tester) async {
    await _pumpHomePage(tester);

    await tester.tap(find.text('Билеты'));
    await tester.pumpAndSettle();

    expect(find.text('Мои билеты'), findsOneWidget);
    expect(find.text('У вас пока нет билетов'), findsOneWidget);
    expect(find.text('Купить билет'), findsOneWidget);
  });
}

Future<void> _pumpHomePage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    buildTestApp(
      child: HomePage(
        newsController: NewsFeedController(
          repository: const _StaticNewsRepository(),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _StaticNewsRepository implements NewsRepository {
  const _StaticNewsRepository();

  @override
  Future<NewsItem> getNewsDetails(String newsId) async {
    throw StateError('No news details in ticket test.');
  }

  @override
  Future<List<NewsItem>> listNotificationHistory({
    required int limit,
    required int offset,
  }) async {
    return const [];
  }

  @override
  Future<List<NewsItem>> listPromotedNews({
    required int limit,
    required int offset,
  }) async {
    return const [];
  }

  @override
  Future<void> trackNewsEvent({
    required String newsId,
    required NewsEventType eventType,
  }) async {}
}

class _FakeTicketPurchaseRepository implements TicketPurchaseRepository {
  const _FakeTicketPurchaseRepository();

  @override
  Future<Result<TicketPaymentStart>> startFreedomPayment({
    required List<TicketPaymentLineItemPayload> items,
    required DateTime? visitDate,
    required String idempotencyKey,
  }) async {
    return const Success<TicketPaymentStart>(
      TicketPaymentStart(
        paymentId: 'payment-test',
        localOrderId: 'order-test',
        externalPaymentId: 'fp-test',
        paymentUrl: 'https://pay.test/order-test',
        status: TicketPaymentStatusValue.pending,
      ),
    );
  }

  @override
  Future<Result<TicketPaymentStatus>> getPaymentStatus(String paymentId) async {
    return const Success<TicketPaymentStatus>(
      TicketPaymentStatus(
        paymentId: 'payment-test',
        localOrderId: 'order-test',
        externalPaymentId: 'fp-test',
        amountTenge: 2700,
        currency: 'KZT',
        status: TicketPaymentStatusValue.pending,
        failureReason: null,
        paidAt: null,
      ),
    );
  }

  @override
  Future<Result<List<PurchasedTicket>>> listPurchasedTickets() async {
    return const Success<List<PurchasedTicket>>([]);
  }
}

class _FakeIssuedTicketRepository implements IssuedTicketRepository {
  const _FakeIssuedTicketRepository();

  @override
  Future<List<IssuedTicket>> listIssuedTickets() async => const [];

  @override
  Future<IssuedTicket> getIssuedTicket(String ticketId) async {
    throw StateError('No ticket details in purchase flow test.');
  }
}
