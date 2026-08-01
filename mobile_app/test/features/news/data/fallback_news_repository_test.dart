import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/features/news/data/fallback_news_repository.dart';
import 'package:star_kids_mobile/features/news/domain/news_item.dart';
import 'package:star_kids_mobile/features/news/domain/news_repository.dart';

void main() {
  final liveItem = NewsItem(
    id: 'live',
    title: 'Live news',
    imageUrl: 'https://example.com/live.jpg',
    createdAt: DateTime.utc(2026),
  );
  final demoItem = NewsItem(
    id: 'demo',
    title: 'Demo news',
    imageUrl: 'assets/images/demo.jpg',
    createdAt: DateTime.utc(2026),
  );

  test('keeps non-empty API news', () async {
    final repository = FallbackNewsRepository(
      primary: _NewsRepository(items: [liveItem]),
      fallbackItems: [demoItem],
    );

    final result = await repository.listPromotedNews(limit: 6, offset: 0);

    expect(result, [liveItem]);
  });

  test('uses demo news for an empty first page and resolves details', () async {
    final repository = FallbackNewsRepository(
      primary: const _NewsRepository(items: []),
      fallbackItems: [demoItem],
    );

    final result = await repository.listPromotedNews(limit: 6, offset: 0);
    final details = await repository.getNewsDetails('demo');

    expect(result, [demoItem]);
    expect(details, same(demoItem));
  });
}

class _NewsRepository implements NewsRepository {
  const _NewsRepository({required this.items});

  final List<NewsItem> items;

  @override
  Future<NewsItem> getNewsDetails(String newsId) async => items.first;

  @override
  Future<List<NewsItem>> listNotificationHistory({
    required int limit,
    required int offset,
  }) async =>
      items;

  @override
  Future<List<NewsItem>> listPromotedNews({
    required int limit,
    required int offset,
  }) async =>
      items;

  @override
  Future<void> trackNewsEvent({
    required String newsId,
    required NewsEventType eventType,
  }) async {}
}
