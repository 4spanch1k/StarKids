class BirthdayRequestPayload {
  const BirthdayRequestPayload({
    required this.branchId,
    required this.name,
    required this.phone,
    required this.preferredDate,
    required this.guestCount,
    this.packageId,
    this.comment,
  });

  final String branchId;
  final String? packageId;
  final String name;
  final String phone;
  final DateTime preferredDate;
  final int guestCount;
  final String? comment;
}
