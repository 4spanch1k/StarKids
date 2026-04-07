class BranchContactLinks {
  const BranchContactLinks({
    required this.branchId,
    required this.mapUrl,
    required this.routeLabel,
    this.parkingHint,
    this.arrivalHint,
  });

  final String branchId;
  final String mapUrl;
  final String routeLabel;
  final String? parkingHint;
  final String? arrivalHint;
}
