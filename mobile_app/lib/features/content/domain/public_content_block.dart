class PublicContentBlock {
  const PublicContentBlock({
    required this.id,
    required this.surface,
    required this.key,
    required this.title,
    required this.body,
    this.ctaLabel,
  });

  final String id;
  final String surface;
  final String key;
  final String title;
  final String body;
  final String? ctaLabel;
}
