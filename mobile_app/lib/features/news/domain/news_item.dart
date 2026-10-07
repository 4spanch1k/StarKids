class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String? description;
  final DateTime createdAt;
}
