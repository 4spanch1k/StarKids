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
  });

  final String id;
  final String? newsId;
  final NotificationType type;
  final String title;
  final String? description;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;

  bool get opensNewsDetails {
    return type == NotificationType.news &&
        (newsId?.trim().isNotEmpty ?? false);
  }
}
