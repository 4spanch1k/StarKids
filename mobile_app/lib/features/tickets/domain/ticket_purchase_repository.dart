import '../../../core/utils/result.dart';
import 'ticket_purchase.dart';

abstract interface class TicketPurchaseRepository {
  Future<Result<TicketCheckoutQuote>> getCheckoutQuote({
    required List<TicketPaymentLineItemPayload> items,
    required DateTime visitDate,
    required int requestedBonusAmount,
  });

  Future<Result<TicketPaymentStart>> startFreedomPayment({
    required List<TicketPaymentLineItemPayload> items,
    required DateTime visitDate,
    required String idempotencyKey,
    required int requestedBonusAmount,
  });

  Future<Result<TicketPaymentStatus>> getPaymentStatus(String paymentId);

  Future<Result<List<PurchasedTicket>>> listPurchasedTickets();
}
