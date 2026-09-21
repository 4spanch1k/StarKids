import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/core/storage/local_storage.dart';
import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/tickets/domain/ticket_purchase.dart';
import 'package:star_kids_mobile/features/tickets/domain/ticket_purchase_repository.dart';
import 'package:star_kids_mobile/features/tickets/presentation/controllers/payment_return_coordinator.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'pending_payment_id': 'payment-1',
    });
  });

  test('success deep link polls backend and emits paid status', () async {
    final repository = _FakeTicketPurchaseRepository(
      status: const TicketPaymentStatus(
        paymentId: 'payment-1',
        localOrderId: 'order-1',
        externalPaymentId: 'external-1',
        amountTenge: 1000,
        currency: 'KZT',
        status: TicketPaymentStatusValue.paid,
        failureReason: null,
        paidAt: null,
      ),
    );
    final coordinator = PaymentReturnCoordinator(
      purchaseRepository: repository,
      localStorage: LocalStorage(),
    );
    final events = <PaymentReturnEvent>[];
    final subscription = coordinator.events.listen(events.add);

    await coordinator.handleRawLink('starkids://payments/success');
    await subscription.cancel();

    expect(repository.requestedPaymentIds, ['payment-1']);
    expect(events, hasLength(1));
    expect(events.single.isPaid, isTrue);
    expect(
      await LocalStorage().readPendingPaymentId(),
      isNull,
    );
    expect(await LocalStorage().readPendingPaymentKind(), isNull);
  });

  test('persisted pass kind survives a cold-start deep link', () async {
    final storage = LocalStorage();
    await storage.savePendingPaymentKind(PaymentCheckoutKind.pass.name);
    final coordinator = PaymentReturnCoordinator(
      purchaseRepository: _FakeTicketPurchaseRepository(
        status: const TicketPaymentStatus(
          paymentId: 'payment-1',
          localOrderId: 'order-1',
          externalPaymentId: null,
          amountTenge: 1000,
          currency: 'KZT',
          status: TicketPaymentStatusValue.paid,
          failureReason: null,
          paidAt: null,
        ),
      ),
      localStorage: storage,
    );
    final events = <PaymentReturnEvent>[];
    final subscription = coordinator.events.listen(events.add);

    await coordinator.handleRawLink('starkids://payments/success');
    await subscription.cancel();

    expect(events.single.checkoutKind, PaymentCheckoutKind.pass);
  });

  test('legacy pending payment without kind defaults to tickets', () async {
    final coordinator = PaymentReturnCoordinator(
      purchaseRepository: _FakeTicketPurchaseRepository(
        status: const TicketPaymentStatus(
          paymentId: 'payment-1',
          localOrderId: 'order-1',
          externalPaymentId: null,
          amountTenge: 1000,
          currency: 'KZT',
          status: TicketPaymentStatusValue.paid,
          failureReason: null,
          paidAt: null,
        ),
      ),
      localStorage: LocalStorage(),
    );
    final events = <PaymentReturnEvent>[];
    final subscription = coordinator.events.listen(events.add);

    await coordinator.handleRawLink('starkids://payments/success');
    await subscription.cancel();

    expect(events.single.checkoutKind, PaymentCheckoutKind.ticket);
  });

  test('completeRegisteredPayment clears only the matching persisted payment',
      () async {
    final storage = LocalStorage();
    final coordinator = PaymentReturnCoordinator(
      purchaseRepository: _FakeTicketPurchaseRepository(
        status: _status(TicketPaymentStatusValue.paid, paymentId: 'payment-x'),
      ),
      localStorage: storage,
    );

    await storage.savePendingPaymentId('payment-x');
    await storage.savePendingPaymentKind(PaymentCheckoutKind.pass.name);
    await coordinator.completeRegisteredPayment('payment-x');

    expect(await storage.readPendingPaymentId(), isNull);
    expect(await storage.readPendingPaymentKind(), isNull);
  });

  test('completeRegisteredPayment does not clear a newer pending payment',
      () async {
    final storage = LocalStorage();
    final coordinator = PaymentReturnCoordinator(
      purchaseRepository: _FakeTicketPurchaseRepository(
        status: _status(TicketPaymentStatusValue.paid, paymentId: 'payment-x'),
      ),
      localStorage: storage,
    );

    await storage.savePendingPaymentId('payment-y');
    await storage.savePendingPaymentKind(PaymentCheckoutKind.ticket.name);
    await coordinator.completeRegisteredPayment('payment-x');

    expect(await storage.readPendingPaymentId(), 'payment-y');
    expect(
      await storage.readPendingPaymentKind(),
      PaymentCheckoutKind.ticket.name,
    );
  });
}

TicketPaymentStatus _status(
  TicketPaymentStatusValue status, {
  required String paymentId,
}) {
  return TicketPaymentStatus(
    paymentId: paymentId,
    localOrderId: 'order-$paymentId',
    externalPaymentId: null,
    amountTenge: 1000,
    currency: 'KZT',
    status: status,
    failureReason: null,
    paidAt: null,
  );
}

class _FakeTicketPurchaseRepository implements TicketPurchaseRepository {
  _FakeTicketPurchaseRepository({required this.status});

  final TicketPaymentStatus status;
  final requestedPaymentIds = <String>[];

  @override
  Future<Result<TicketPaymentStatus>> getPaymentStatus(String paymentId) async {
    requestedPaymentIds.add(paymentId);
    return Success(status);
  }

  @override
  Future<Result<TicketCheckoutQuote>> getCheckoutQuote({
    required List<TicketPaymentLineItemPayload> items,
    required DateTime visitDate,
    required int requestedBonusAmount,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<TicketPaymentStart>> startFreedomPayment({
    required List<TicketPaymentLineItemPayload> items,
    required DateTime visitDate,
    required String idempotencyKey,
    required int requestedBonusAmount,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<List<PurchasedTicket>>> listPurchasedTickets() =>
      throw UnimplementedError();
}
