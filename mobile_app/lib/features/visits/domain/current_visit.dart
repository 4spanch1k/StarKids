class CurrentVisit {
  const CurrentVisit({
    required this.visitId,
    required this.branchId,
    required this.branchName,
    required this.status,
    required this.startedAt,
  });

  final String visitId;
  final String branchId;
  final String branchName;
  final String status;
  final DateTime startedAt;
}
