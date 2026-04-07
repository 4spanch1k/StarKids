class PromotionOffer {
  const PromotionOffer({
    required this.id,
    required this.title,
    required this.description,
    required this.badgeLabel,
    required this.imagePath,
    required this.branchIds,
    required this.ctaLabel,
  });

  final String id;
  final String title;
  final String description;
  final String badgeLabel;
  final String imagePath;
  final List<String> branchIds;
  final String ctaLabel;
}
