import '../domain/ticket_purchase.dart';

class FreedomPaymentStartDto {
  const FreedomPaymentStartDto({
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
  final String status;

  factory FreedomPaymentStartDto.fromJson(Map<String, dynamic> json) {
    return FreedomPaymentStartDto(
      paymentId: json['paymentId'] as String,
      localOrderId: json['localOrderId'] as String,
      externalPaymentId: json['externalPaymentId'] as String?,
      paymentUrl: json['paymentUrl'] as String,
      status: json['status'] as String? ?? 'pending',
    );
  }

  TicketPaymentStart toDomain() {
    return TicketPaymentStart(
      paymentId: paymentId,
      localOrderId: localOrderId,
      externalPaymentId: externalPaymentId,
      paymentUrl: paymentUrl,
      status: ticketPaymentStatusFromJson(status),
    );
  }
}

class TicketPaymentStatusDto {
  const TicketPaymentStatusDto({
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
  final String status;
  final String? failureReason;
  final DateTime? paidAt;

  factory TicketPaymentStatusDto.fromJson(Map<String, dynamic> json) {
    return TicketPaymentStatusDto(
      paymentId: json['paymentId'] as String,
      localOrderId: json['localOrderId'] as String,
      externalPaymentId: json['externalPaymentId'] as String?,
      amountTenge: json['amountTenge'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'KZT',
      status: json['status'] as String? ?? 'unknown',
      failureReason: json['failureReason'] as String?,
      paidAt: _parseDateTime(json['paidAt']),
    );
  }

  TicketPaymentStatus toDomain() {
    return TicketPaymentStatus(
      paymentId: paymentId,
      localOrderId: localOrderId,
      externalPaymentId: externalPaymentId,
      amountTenge: amountTenge,
      currency: currency,
      status: ticketPaymentStatusFromJson(status),
      failureReason: failureReason,
      paidAt: paidAt,
    );
  }
}

class PurchasedTicketsDto {
  const PurchasedTicketsDto({required this.items});

  final List<PurchasedTicketDto> items;

  factory PurchasedTicketsDto.fromJson(Map<String, dynamic> json) {
    return PurchasedTicketsDto(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PurchasedTicketDto.fromJson)
          .toList(),
    );
  }

  List<PurchasedTicket> toDomain() {
    return items.map((item) => item.toDomain()).toList();
  }
}

class PurchasedTicketDto {
  const PurchasedTicketDto({
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
  final List<PurchasedTicketLineItemDto> items;

  factory PurchasedTicketDto.fromJson(Map<String, dynamic> json) {
    return PurchasedTicketDto(
      paymentId: json['paymentId'] as String,
      localOrderId: json['localOrderId'] as String,
      branchId: json['branchId'] as String,
      branchName: json['branchName'] as String? ?? 'Star Kids',
      visitDate: _parseDateTime(json['visitDate']),
      amountTenge: json['amountTenge'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'KZT',
      paidAt: _parseDateTime(json['paidAt']),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PurchasedTicketLineItemDto.fromJson)
          .toList(),
    );
  }

  PurchasedTicket toDomain() {
    return PurchasedTicket(
      paymentId: paymentId,
      localOrderId: localOrderId,
      branchId: branchId,
      branchName: branchName,
      visitDate: visitDate,
      amountTenge: amountTenge,
      currency: currency,
      paidAt: paidAt,
      items: items.map((item) => item.toDomain()).toList(),
    );
  }
}

class PurchasedTicketLineItemDto {
  const PurchasedTicketLineItemDto({
    required this.ticketItemId,
    required this.title,
    required this.priceTenge,
    required this.quantity,
  });

  final String ticketItemId;
  final String title;
  final int priceTenge;
  final int quantity;

  factory PurchasedTicketLineItemDto.fromJson(Map<String, dynamic> json) {
    return PurchasedTicketLineItemDto(
      ticketItemId: json['ticketItemId'] as String,
      title: json['title'] as String? ?? 'Билет',
      priceTenge: json['priceTenge'] as int? ?? 0,
      quantity: json['quantity'] as int? ?? 0,
    );
  }

  PurchasedTicketLineItem toDomain() {
    return PurchasedTicketLineItem(
      ticketItemId: ticketItemId,
      title: title,
      priceTenge: priceTenge,
      quantity: quantity,
    );
  }
}

DateTime? _parseDateTime(Object? rawValue) {
  if (rawValue is! String || rawValue.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(rawValue);
}
