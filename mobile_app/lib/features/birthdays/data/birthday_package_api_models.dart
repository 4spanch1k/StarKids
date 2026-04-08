import '../domain/birthday_package.dart';

class BirthdayPackageSummaryDto {
  const BirthdayPackageSummaryDto({
    required this.id,
    required this.branchId,
    required this.name,
    required this.priceLabel,
    required this.guestCapacityLabel,
    required this.imageUrl,
    required this.isFeatured,
  });

  final String id;
  final String branchId;
  final String name;
  final String priceLabel;
  final String guestCapacityLabel;
  final String? imageUrl;
  final bool isFeatured;

  factory BirthdayPackageSummaryDto.fromJson(Map<String, dynamic> json) {
    return BirthdayPackageSummaryDto(
      id: json['id'] as String,
      branchId: json['branch_id'] as String,
      name: json['name'] as String,
      priceLabel: json['price_label'] as String,
      guestCapacityLabel: json['guest_capacity_label'] as String,
      imageUrl: json['image_url'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }
}

class BirthdayPackageDetailDto {
  const BirthdayPackageDetailDto({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.guestCapacityLabel,
    required this.description,
    required this.highlights,
    required this.imageUrl,
    required this.isFeatured,
  });

  final String id;
  final String name;
  final String priceLabel;
  final String guestCapacityLabel;
  final String description;
  final List<String> highlights;
  final String? imageUrl;
  final bool isFeatured;

  factory BirthdayPackageDetailDto.fromJson(Map<String, dynamic> json) {
    return BirthdayPackageDetailDto(
      id: json['id'] as String,
      name: json['name'] as String,
      priceLabel: json['price_label'] as String,
      guestCapacityLabel: json['guest_capacity_label'] as String,
      description: json['description'] as String,
      highlights: (json['highlights'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
      imageUrl: json['image_url'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }

  BirthdayPackage toDomain() {
    return BirthdayPackage(
      id: id,
      name: name,
      priceLabel: priceLabel,
      guestLabel: guestCapacityLabel,
      description: description.trim(),
      highlights: highlights
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      imagePath: imageUrl?.trim() ?? '',
      isFeatured: isFeatured,
    );
  }
}
