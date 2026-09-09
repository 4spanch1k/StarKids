import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/features/news/data/api_news_repository.dart';
import 'package:star_kids_mobile/features/news/domain/news_item.dart';
import 'package:star_kids_mobile/features/news/domain/news_repository.dart';
import 'package:star_kids_mobile/features/news/presentation/controllers/news_feed_controller.dart';

void main() {
  setUp(() {
    NewsFeedController.clearCache();
  });

  test('reuses valid in-memory cache inside TTL', () async {
    final repository = _StubNewsRepository(
      promotedItems: [
        NewsItem(
          id: 'news-1',
          title: 'Cached news',
          imageUrl: 'https://cdn.example/news-1.jpg',
          description: 'Cached body',
          createdAt: DateTime.utc(2026, 4, 21),
        ),
      ],
    );

    final firstController = NewsFeedController(
      repository: repository,
      feedKind: NewsFeedKind.promotions,
      cacheTtl: const Duration(minutes: 3),
    );
    await firstController.bootstrap();

    final secondController = NewsFeedController(
      repository: repository,
      feedKind: NewsFeedKind.promotions,
      cacheTtl: const Duration(minutes: 3),
    );
    await secondController.bootstrap();

    expect(repository.promotedCalls, 1);
    expect(secondController.items, hasLength(1));
    expect(secondController.items.first.title, 'Cached news');
  });

  test('falls back to stale cache when network is offline', () async {
    final seededRepository = _StubNewsRepository(
      promotedItems: [
        NewsItem(
          id: 'news-1',
          title: 'Offline cache',
          imageUrl: 'https://cdn.example/news-1.jpg',
          description: 'Cached body',
          createdAt: DateTime.utc(2026, 4, 21),
        ),
      ],
    );
    final seededController = NewsFeedController(
      repository: seededRepository,
      feedKind: NewsFeedKind.promotions,
      cacheTtl: const Duration(minutes: 3),
    );
    await seededController.bootstrap();

    final offlineRepository = _StubNewsRepository(
      promotedItems: const [],
      throwNetworkError: true,
    );
    final offlineController = NewsFeedController(
      repository: offlineRepository,
      feedKind: NewsFeedKind.promotions,
      cacheTtl: Duration.zero,
    );
    await offlineController.bootstrap();

    expect(offlineRepository.promotedCalls, 1);
    expect(offlineController.isOffline, isTrue);
    expect(offlineController.items, hasLength(1));
    expect(offlineController.errorMessage,
        'Нет соединения\nПоказаны последние данные');
  });

  test('forceRefresh bypasses valid TTL cache', () async {
    final repository = _StubNewsRepository(
      promotedItems: [
        NewsItem(
          id: 'news-1',
          title: 'Version 1',
          imageUrl: 'https://cdn.example/news-1.jpg',
          description: 'First payload',
          createdAt: DateTime.utc(2026, 4, 21),
        ),
      ],
    );

    final controller = NewsFeedController(
      repository: repository,
      feedKind: NewsFeedKind.promotions,
      cacheTtl: const Duration(minutes: 3),
    );
    await controller.bootstrap();

    repository.promotedItems
      ..clear()
      ..add(
        NewsItem(
          id: 'news-2',
          title: 'Version 2',
          imageUrl: 'https://cdn.example/news-2.jpg',
          description: 'Fresh payload',
          createdAt: DateTime.utc(2026, 4, 22),
        ),
      );

    await controller.forceRefresh();

    expect(repository.promotedCalls, 2);
    expect(controller.items.single.id, 'news-2');
  });
}

class _StubNewsRepository implements NewsRepository {
  _StubNewsRepository({
    required this.promotedItems,
    this.throwNetworkError = false,
  });

  final List<NewsItem> promotedItems;
  final bool throwNetworkError;
  int promotedCalls = 0;

  @override
  Future<NewsItem> getNewsDetails(String newsId) async {
    return promotedItems.firstWhere((item) => item.id == newsId);
  }

  @override
  Future<List<NewsItem>> listNotificationHistory({
    required int limit,
    required int offset,
  }) async {
    return promotedItems.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<List<NewsItem>> listPromotedNews({
    required int limit,
    required int offset,
  }) async {
    promotedCalls += 1;
    if (throwNetworkError) {
      throw const NewsNetworkException('Network is unavailable');
    }
    return promotedItems.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<void> trackNewsEvent({
    required String newsId,
    required NewsEventType eventType,
  }) async {}
}
