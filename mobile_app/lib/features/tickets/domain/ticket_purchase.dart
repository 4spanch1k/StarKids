enum TicketPaymentStatusValue {
  created,
  pending,
  paid,
  failed,
  canceled,
  expired,
  unknown,
}

class TicketPaymentLineItemPayload {
  const TicketPaymentLineItemPayload({
    required this.ticketItemId,
    required this.quantity,
  });

  final String ticketItemId;
  final int quantity;
}

class TicketPaymentStart {
  const TicketPaymentStart({
    required this.paymentId,
    required this.localOrderId,
    required this.externalPaymentId,
    required this.paymentUrl,
    required this.status,
  });

  final String paymentId;
  final String localOrderId;
  final String? externalPaymentId;
  final String paymentUrl;
  final TicketPaymentStatusValue status;
}

class TicketPaymentStatus {
  const TicketPaymentStatus({
    required this.paymentId,
    required this.localOrderId,
    required this.externalPaymentId,
    required this.amountTenge,
    required this.currency,
    required this.status,
    required this.failureReason,
    required this.paidAt,
  });

  final String paymentId;
  final String localOrderId;
  final String? externalPaymentId;
  final int amountTenge;
  final String currency;
  final TicketPaymentStatusValue status;
  final String? failureReason;
  final DateTime? paidAt;

  bool get isFinal =>
      status == TicketPaymentStatusValue.paid ||
      status == TicketPaymentStatusValue.failed ||
      status == TicketPaymentStatusValue.canceled ||
      status == TicketPaymentStatusValue.expired;
}

class PurchasedTicketLineItem {
  const PurchasedTicketLineItem({
    required this.ticketItemId,
    required this.title,
    required this.priceTenge,
    required this.quantity,
  });

  final String ticketItemId;
  final String title;
  final int priceTenge;
  final int quantity;
}

class PurchasedTicket {
  const PurchasedTicket({
    required this.paymentId,
    required this.localOrderId,
    required this.branchId,
    required this.branchName,
    required this.visitDate,
    required this.amountTenge,
    required this.currency,
    required this.paidAt,
    required this.items,
  });

  final String paymentId;
  final String localOrderId;
  final String branchId;
  final String branchName;
  final DateTime? visitDate;
  final int amountTenge;
  final String currency;
  final DateTime? paidAt;
  final List<PurchasedTicketLineItem> items;
}

TicketPaymentStatusValue ticketPaymentStatusFromJson(String? rawStatus) {
  return switch (rawStatus) {
    'created' => TicketPaymentStatusValue.created,
    'pending' => TicketPaymentStatusValue.pending,
    'paid' => TicketPaymentStatusValue.paid,
    'failed' => TicketPaymentStatusValue.failed,
    'canceled' => TicketPaymentStatusValue.canceled,
    'expired' => TicketPaymentStatusValue.expired,
    _ => TicketPaymentStatusValue.unknown,
  };
}
