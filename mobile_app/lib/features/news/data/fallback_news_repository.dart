import '../domain/news_item.dart';
import '../domain/news_repository.dart';

class FallbackNewsRepository implements NewsRepository {
  const FallbackNewsRepository({
    required NewsRepository primary,
    required List<NewsItem> fallbackItems,
  })  : _primary = primary,
        _fallbackItems = fallbackItems;

  final NewsRepository _primary;
  final List<NewsItem> _fallbackItems;

  @override
  Future<List<NewsItem>> listPromotedNews({
    required int limit,
    required int offset,
  }) async {
    try {
      final items = await _primary.listPromotedNews(
        limit: limit,
        offset: offset,
      );
      if (items.isNotEmpty) {
        return items;
      }
      if (offset > 0) {
        return const [];
      }
    } catch (_) {
      // Fall through to local demo news when the API is unavailable or empty.
      if (offset > 0) {
        return const [];
      }
    }
    return _sliceFallback(limit: limit, offset: offset);
  }

  @override
  Future<List<NewsItem>> listNotificationHistory({
    required int limit,
    required int offset,
  }) {
    return _primary.listNotificationHistory(limit: limit, offset: offset);
  }

  @override
  Future<NewsItem> getNewsDetails(String newsId) async {
    for (final item in _fallbackItems) {
      if (item.id == newsId) {
        return item;
      }
    }
    return _primary.getNewsDetails(newsId);
  }

  @override
  Future<void> trackNewsEvent({
    required String newsId,
    required NewsEventType eventType,
  }) async {
    if (_fallbackItems.any((item) => item.id == newsId)) {
      return;
    }
    await _primary.trackNewsEvent(newsId: newsId, eventType: eventType);
  }

  List<NewsItem> _sliceFallback({required int limit, required int offset}) {
    if (offset >= _fallbackItems.length) {
      return const [];
    }
    final end = (offset + limit).clamp(0, _fallbackItems.length);
    return _fallbackItems.sublist(offset, end);
  }
}
