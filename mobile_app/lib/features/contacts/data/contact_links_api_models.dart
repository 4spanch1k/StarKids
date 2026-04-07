import '../domain/branch_contact_links.dart';

class BranchContactLinksDto {
  const BranchContactLinksDto({
    required this.branchId,
    required this.address,
    required this.phone,
    required this.whatsappPhone,
    required this.mapUrl,
    required this.routeLabel,
    required this.parkingHint,
    required this.arrivalHint,
  });

  final String branchId;
  final String address;
  final String phone;
  final String whatsappPhone;
  final String mapUrl;
  final String routeLabel;
  final String? parkingHint;
  final String? arrivalHint;

  factory BranchContactLinksDto.fromJson(Map<String, dynamic> json) {
    return BranchContactLinksDto(
      branchId: json['branch_id'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String,
      whatsappPhone: json['whatsapp_phone'] as String,
      mapUrl: json['map_url'] as String,
      routeLabel: json['route_label'] as String,
      parkingHint: json['parking_hint'] as String?,
      arrivalHint: json['arrival_hint'] as String?,
    );
  }

  BranchContactLinks toDomain() {
    return BranchContactLinks(
      branchId: branchId,
      address: address,
      phone: phone,
      whatsAppPhone: whatsappPhone,
      mapUrl: mapUrl,
      routeLabel: routeLabel,
      parkingHint: parkingHint,
      arrivalHint: arrivalHint,
    );
  }
}
