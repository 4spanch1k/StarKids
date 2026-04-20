import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/app/theme/app_theme.dart';
import 'package:star_kids_mobile/features/news/domain/news_item.dart';
import 'package:star_kids_mobile/features/news/domain/news_repository.dart';
import 'package:star_kids_mobile/features/news/presentation/controllers/news_feed_controller.dart';
import 'package:star_kids_mobile/features/notifications/presentation/pages/notifications_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders news list with image, title and date', (
    WidgetTester tester,
  ) async {
    final controller = NewsFeedController(
      repository: _FakeNewsRepository(
        items: [
          NewsItem(
            id: 'news-1',
            title: 'Открылась новая игровая зона',
            imageUrl: 'https://cdn.example/news-1.jpg',
            description: 'Теперь в филиале еще больше активностей.',
            createdAt: DateTime.utc(2026, 4, 20),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _TestApp(
        child: NotificationsPage(newsController: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Новости'), findsOneWidget);
    expect(find.text('Открылась новая игровая зона'), findsOneWidget);
    expect(find.text('20.04.2026'), findsOneWidget);
  });

  testWidgets('renders empty state when news feed has no items', (
    WidgetTester tester,
  ) async {
    final controller = NewsFeedController(
      repository: const _FakeNewsRepository(items: []),
    );

    await tester.pumpWidget(
      _TestApp(
        child: NotificationsPage(newsController: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Пока нет новостей'), findsOneWidget);
  });

  testWidgets('renders error state with retry action', (
    WidgetTester tester,
  ) async {
    final controller = NewsFeedController(
      repository: const _ThrowingNewsRepository(),
    );

    await tester.pumpWidget(
      _TestApp(
        child: NotificationsPage(newsController: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Не удалось загрузить новости'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('renders loading indicator before feed finishes bootstrap', (
    WidgetTester tester,
  ) async {
    final controller = NewsFeedController(
      repository: _DelayedNewsRepository(
        completer: Completer<List<NewsItem>>(),
      ),
    );

    await tester.pumpWidget(
      _TestApp(
        child: NotificationsPage(newsController: controller),
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

class _FakeNewsRepository implements NewsRepository {
  const _FakeNewsRepository({
    required this.items,
  });

  final List<NewsItem> items;

  @override
  Future<List<NewsItem>> listNews() async => items;
}

class _ThrowingNewsRepository implements NewsRepository {
  const _ThrowingNewsRepository();

  @override
  Future<List<NewsItem>> listNews() async {
    throw StateError('boom');
  }
}

class _DelayedNewsRepository implements NewsRepository {
  const _DelayedNewsRepository({
    required this.completer,
  });

  final Completer<List<NewsItem>> completer;

  @override
  Future<List<NewsItem>> listNews() => completer.future;
}
