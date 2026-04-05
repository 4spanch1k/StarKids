class BirthdayPackage {
  const BirthdayPackage({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.guestLabel,
    required this.description,
    required this.highlights,
    required this.imagePath,
    this.isFeatured = false,
  });

  final String id;
  final String name;
  final String priceLabel;
  final String guestLabel;
  final String description;
  final List<String> highlights;
  final String imagePath;
  final bool isFeatured;
}

