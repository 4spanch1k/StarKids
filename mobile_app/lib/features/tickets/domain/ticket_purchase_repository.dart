import '../../../core/utils/result.dart';
import 'ticket_purchase.dart';

abstract interface class TicketPurchaseRepository {
  Future<Result<TicketPaymentStart>> startFreedomPayment({
    required List<TicketPaymentLineItemPayload> items,
    required DateTime? visitDate,
  });

  Future<Result<TicketPaymentStatus>> getPaymentStatus(String paymentId);

  Future<Result<List<PurchasedTicket>>> listPurchasedTickets();
}
