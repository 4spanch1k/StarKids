import '../../domain/news_item.dart';

class NewsDetailsPageArgs {
  const NewsDetailsPageArgs({
    required this.newsId,
    this.initialItem,
  });

  final String newsId;
  final NewsItem? initialItem;
}
