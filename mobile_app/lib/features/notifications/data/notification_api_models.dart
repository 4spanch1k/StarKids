import '../domain/app_notification.dart';

class AppNotificationDto {
  const AppNotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    required this.isRead,
    this.newsId,
    this.description,
    this.imageUrl,
  });

  final String id;
  final String? newsId;
  final NotificationType type;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;

  factory AppNotificationDto.fromJson(Map<String, dynamic> json) {
    return AppNotificationDto(
      id: json['id'] as String? ?? '',
      newsId: json['news_id'] as String?,
      type: NotificationType.fromWireValue(json['type'] as String? ?? 'news'),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  AppNotification toDomain() {
    return AppNotification(
      id: id,
      newsId: newsId,
      type: type,
      title: title,
      description: description,
      imageUrl: imageUrl,
      createdAt: createdAt,
      isRead: isRead,
    );
  }
}
