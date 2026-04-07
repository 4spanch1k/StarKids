import '../domain/branch_option.dart';
import 'branch_seed_data.dart';

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
    final fallback = getBranchById(id);

    return BranchOption(
      id: id,
      name: name,
      shortLabel: shortLabel,
      address: address,
      workingHours: workingHours,
      description: fallback.description,
      phone: fallback.phone,
      whatsAppPhone: fallback.whatsAppPhone,
      heroImagePath: fallback.heroImagePath,
      galleryImagePaths: fallback.galleryImagePaths,
      facilities: fallback.facilities,
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
    final fallback = getBranchById(id);

    return BranchOption(
      id: id,
      name: name,
      shortLabel: shortLabel,
      address: address,
      workingHours: workingHours,
      description: description,
      phone: phone,
      whatsAppPhone: whatsappPhone,
      heroImagePath: heroImageUrl?.trim().isNotEmpty == true
          ? heroImageUrl!
          : fallback.heroImagePath,
      galleryImagePaths: galleryImageUrls.isNotEmpty
          ? galleryImageUrls
          : fallback.galleryImagePaths,
      facilities: facilities.isNotEmpty ? facilities : fallback.facilities,
    );
  }
}
