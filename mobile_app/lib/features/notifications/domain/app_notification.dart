import 'notification_destination.dart';

enum NotificationType {
  news,
  system,
  promo;

  static NotificationType fromWireValue(String rawValue) {
    switch (rawValue.trim().toLowerCase()) {
      case 'system':
        return NotificationType.system;
      case 'promo':
        return NotificationType.promo;
      case 'news':
      default:
        return NotificationType.news;
    }
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    required this.isRead,
    this.newsId,
    this.description,
    this.imageUrl,
    this.destinationType,
    this.destinationId,
  });

  final String id;
  final String? newsId;
  final NotificationType type;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;
  final String? destinationType;
  final String? destinationId;

  NotificationDestination? get destination =>
      NotificationDestination.fromPayload({
        'destination_type': destinationType,
        'destination_id': destinationId,
        'type': type.name,
        'news_id': newsId,
      });

  bool get opensNewsDetails {
    return type == NotificationType.news &&
        (newsId?.trim().isNotEmpty ?? false);
  }
}
