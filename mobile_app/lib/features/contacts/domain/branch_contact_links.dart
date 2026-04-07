class BranchContactLinks {
  const BranchContactLinks({
    required this.branchId,
    required this.address,
    required this.phone,
    required this.whatsAppPhone,
    required this.mapUrl,
    required this.routeLabel,
    this.parkingHint,
    this.arrivalHint,
  });

  final String branchId;
  final String address;
  final String phone;
  final String whatsAppPhone;
  final String mapUrl;
  final String routeLabel;
  final String? parkingHint;
  final String? arrivalHint;
}
