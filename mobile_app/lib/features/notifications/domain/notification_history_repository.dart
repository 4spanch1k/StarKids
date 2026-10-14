import 'app_notification.dart';

abstract interface class NotificationHistoryRepository {
  Future<List<AppNotification>> listNotifications({
    required int limit,
    required int offset,
  });
}
