class BirthdayRequestPayload {
  const BirthdayRequestPayload({
    required this.branchId,
    required this.name,
    required this.phone,
    required this.preferredDate,
    required this.guestCount,
    this.childId,
    this.packageId,
    this.comment,
    this.idempotencyKey,
  });

  final String branchId;
  final String? packageId;
  final String name;
  final String phone;
  final DateTime preferredDate;
  final int guestCount;
  final String? childId;
  final String? comment;
  final String? idempotencyKey;
}
