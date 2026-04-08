import '../domain/branch_option.dart';

class BranchSummaryDto {
  const BranchSummaryDto({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortLabel,
    required this.address,
    required this.workingHours,
  });

  final String id;
  final String slug;
  final String name;
  final String shortLabel;
  final String address;
  final String workingHours;

  factory BranchSummaryDto.fromJson(Map<String, dynamic> json) {
    return BranchSummaryDto(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      shortLabel: json['short_label'] as String,
      address: json['address'] as String,
      workingHours: json['working_hours'] as String,
    );
  }

  BranchOption toDomain() {
    return BranchOption(
      id: id,
      name: name,
      shortLabel: shortLabel,
      address: address,
      workingHours: workingHours,
      description: '',
      phone: '',
      whatsAppPhone: '',
      heroImagePath: '',
      galleryImagePaths: const [],
      facilities: const [],
    );
  }
}

class BranchDetailDto {
  const BranchDetailDto({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortLabel,
    required this.address,
    required this.workingHours,
    required this.description,
    required this.phone,
    required this.whatsappPhone,
    required this.heroImageUrl,
    required this.galleryImageUrls,
    required this.facilities,
  });

  final String id;
  final String slug;
  final String name;
  final String shortLabel;
  final String address;
  final String workingHours;
  final String description;
  final String phone;
  final String whatsappPhone;
  final String? heroImageUrl;
  final List<String> galleryImageUrls;
  final List<String> facilities;

  factory BranchDetailDto.fromJson(Map<String, dynamic> json) {
    return BranchDetailDto(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      shortLabel: json['short_label'] as String,
      address: json['address'] as String,
      workingHours: json['working_hours'] as String,
      description: json['description'] as String,
      phone: json['phone'] as String,
      whatsappPhone: json['whatsapp_phone'] as String,
      heroImageUrl: json['hero_image_url'] as String?,
      galleryImageUrls:
          (json['gallery_image_urls'] as List<dynamic>? ?? const [])
              .map((item) => '$item')
              .toList(),
      facilities: (json['facilities'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
    );
  }

  BranchOption toDomain() {
    return BranchOption(
      id: id,
      name: name,
      shortLabel: shortLabel,
      address: address,
      workingHours: workingHours,
      description: description.trim(),
      phone: phone.trim(),
      whatsAppPhone: whatsappPhone.trim(),
      heroImagePath: _normalizeString(heroImageUrl),
      galleryImagePaths: galleryImageUrls
          .map(_normalizeString)
          .where((value) => value.isNotEmpty)
          .toList(),
      facilities: facilities
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }

  static String _normalizeString(String? value) {
    return value?.trim() ?? '';
  }
}
