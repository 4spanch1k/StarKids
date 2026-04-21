import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/app/theme/app_theme.dart';
import 'package:star_kids_mobile/features/notifications/domain/app_notification.dart';
import 'package:star_kids_mobile/features/notifications/domain/notification_history_repository.dart';
import 'package:star_kids_mobile/features/notifications/presentation/controllers/notification_history_controller.dart';
import 'package:star_kids_mobile/features/notifications/presentation/pages/notifications_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NotificationHistoryController.clearCache();
  });

  testWidgets('renders notification list with image, title and date', (
    WidgetTester tester,
  ) async {
    final controller = NotificationHistoryController(
      repository: _FakeNotificationRepository(
        items: [
          AppNotification(
            id: 'notification-1',
            newsId: 'news-1',
            type: NotificationType.news,
            title: 'Открылась новая игровая зона',
            imageUrl: 'https://cdn.example/news-1.jpg',
            description: 'Теперь в филиале еще больше активностей.',
            createdAt: DateTime.utc(2026, 4, 20),
            isRead: false,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _TestApp(
        child: NotificationsPage(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Открылась новая игровая зона'), findsOneWidget);
    expect(find.text('20.04.2026'), findsOneWidget);
    expect(find.text('Новость'), findsOneWidget);
  });

  testWidgets('renders empty state when notification feed has no items', (
    WidgetTester tester,
  ) async {
    final controller = NotificationHistoryController(
      repository: const _FakeNotificationRepository(items: []),
    );

    await tester.pumpWidget(
      _TestApp(
        child: NotificationsPage(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Пока нет уведомлений'), findsOneWidget);
  });

  testWidgets('renders error state with retry action', (
    WidgetTester tester,
  ) async {
    final controller = NotificationHistoryController(
      repository: const _ThrowingNotificationRepository(),
    );

    await tester.pumpWidget(
      _TestApp(
        child: NotificationsPage(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Не удалось загрузить уведомления'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('renders loading indicator before feed finishes bootstrap', (
    WidgetTester tester,
  ) async {
    final controller = NotificationHistoryController(
      repository: _DelayedNotificationRepository(
        completer: Completer<List<AppNotification>>(),
      ),
    );

    await tester.pumpWidget(
      _TestApp(
        child: NotificationsPage(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: child,
    );
  }
}

class _FakeNotificationRepository implements NotificationHistoryRepository {
  const _FakeNotificationRepository({
    required this.items,
  });

  final List<AppNotification> items;

  @override
  Future<List<AppNotification>> listNotifications({
    required int limit,
    required int offset,
  }) async {
    return items.skip(offset).take(limit).toList(growable: false);
  }
}

class _ThrowingNotificationRepository implements NotificationHistoryRepository {
  const _ThrowingNotificationRepository();

  @override
  Future<List<AppNotification>> listNotifications({
    required int limit,
    required int offset,
  }) async {
    throw StateError('boom');
  }
}

class _DelayedNotificationRepository implements NotificationHistoryRepository {
  const _DelayedNotificationRepository({
    required this.completer,
  });

  final Completer<List<AppNotification>> completer;

  @override
  Future<List<AppNotification>> listNotifications({
    required int limit,
    required int offset,
  }) {
    return completer.future;
  }
}
