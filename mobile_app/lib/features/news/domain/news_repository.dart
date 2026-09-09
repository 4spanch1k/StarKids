import 'news_item.dart';

enum NewsEventType {
  click,
  view,
}

abstract interface class NewsRepository {
  Future<List<NewsItem>> listPromotedNews({
    required int limit,
    required int offset,
  });

  Future<List<NewsItem>> listNotificationHistory({
    required int limit,
    required int offset,
  });

  Future<NewsItem> getNewsDetails(String newsId);

  Future<void> trackNewsEvent({
    required String newsId,
    required NewsEventType eventType,
  });
}
