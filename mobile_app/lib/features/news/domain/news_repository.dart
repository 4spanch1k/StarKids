import 'news_item.dart';

abstract interface class NewsRepository {
  Future<List<NewsItem>> listNews();
}
