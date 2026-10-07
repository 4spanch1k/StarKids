class IssuedTicket {
  const IssuedTicket({
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

  bool get isIssued => status == 'issued';
}
