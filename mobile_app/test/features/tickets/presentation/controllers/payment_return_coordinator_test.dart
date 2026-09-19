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
  });
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
