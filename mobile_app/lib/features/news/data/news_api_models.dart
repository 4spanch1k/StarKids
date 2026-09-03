import '../domain/news_item.dart';

class NewsItemDto {
  const NewsItemDto({
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

  factory NewsItemDto.fromJson(Map<String, dynamic> json) {
    return NewsItemDto(
      id: json['news_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      description: json['description'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
    );
  }

  NewsItem toDomain() {
    return NewsItem(
      id: id,
      title: title,
      imageUrl: imageUrl,
      description: description,
      createdAt: createdAt,
    );
  }
}
