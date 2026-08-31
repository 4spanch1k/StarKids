import '../domain/issued_ticket.dart';

class IssuedTicketsDto {
  const IssuedTicketsDto({required this.items});

  final List<IssuedTicketDto> items;

  factory IssuedTicketsDto.fromJson(Map<String, dynamic> json) {
    return IssuedTicketsDto(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(IssuedTicketDto.fromJson)
          .toList(growable: false),
    );
  }
}

class IssuedTicketDto {
  const IssuedTicketDto({
    required this.ticketId,
    required this.ticketNumber,
    required this.ticketItemId,
    required this.title,
    required this.branchId,
    required this.branchName,
    required this.visitDate,
    required this.priceTenge,
    required this.status,
    required this.issuedAt,
  });

  final String ticketId;
  final String ticketNumber;
  final String ticketItemId;
  final String title;
  final String branchId;
  final String branchName;
  final DateTime? visitDate;
  final int priceTenge;
  final String status;
  final DateTime issuedAt;

  factory IssuedTicketDto.fromJson(Map<String, dynamic> json) {
    return IssuedTicketDto(
      ticketId: json['ticketId'] as String,
      ticketNumber: json['ticketNumber'] as String,
      ticketItemId: json['ticketItemId'] as String,
      title: json['title'] as String? ?? 'Билет',
      branchId: json['branchId'] as String,
      branchName: json['branchName'] as String? ?? 'Boom Bala',
      visitDate: _parseDate(json['visitDate']),
      priceTenge: json['priceTenge'] as int? ?? 0,
      status: json['status'] as String? ?? 'issued',
      issuedAt: _parseDate(json['issuedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  IssuedTicket toDomain() {
    return IssuedTicket(
      ticketId: ticketId,
      ticketNumber: ticketNumber,
      ticketItemId: ticketItemId,
      title: title,
      branchId: branchId,
      branchName: branchName,
      visitDate: visitDate,
      priceTenge: priceTenge,
      status: status,
      issuedAt: issuedAt,
    );
  }
}

DateTime? _parseDate(Object? rawValue) {
  if (rawValue is! String || rawValue.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(rawValue);
}
