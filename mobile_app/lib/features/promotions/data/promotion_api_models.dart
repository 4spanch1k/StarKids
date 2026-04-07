import '../domain/promotion_offer.dart';
import 'promotion_seed_data.dart';

class PromotionOfferDto {
  const PromotionOfferDto({
    required this.id,
    required this.title,
    required this.description,
    required this.badgeLabel,
    required this.imageUrl,
    required this.branchIds,
    required this.ctaLabel,
  });

  final String id;
  final String title;
  final String description;
  final String badgeLabel;
  final String? imageUrl;
  final List<String> branchIds;
  final String ctaLabel;

  factory PromotionOfferDto.fromJson(Map<String, dynamic> json) {
    return PromotionOfferDto(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      badgeLabel: json['badge_label'] as String,
      imageUrl: json['image_url'] as String?,
      branchIds: (json['branch_ids'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
      ctaLabel: json['cta_label'] as String,
    );
  }

  PromotionOffer toDomain() {
    PromotionOffer? fallback;
    for (final item in promotionSeedData) {
      if (item.id == id) {
        fallback = item;
        break;
      }
    }

    return PromotionOffer(
      id: id,
      title: title,
      description: description,
      badgeLabel: badgeLabel,
      imagePath: imageUrl?.trim().isNotEmpty == true
          ? imageUrl!
          : (fallback?.imagePath ?? 'assets/images/promo_hero.jpg'),
      branchIds: branchIds,
      ctaLabel: ctaLabel,
    );
  }
}
