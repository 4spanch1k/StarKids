import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/features/news/domain/news_item.dart';
import 'package:star_kids_mobile/features/news/domain/news_repository.dart';
import 'package:star_kids_mobile/features/news/presentation/controllers/news_feed_controller.dart';
import 'package:star_kids_mobile/features/news/presentation/pages/news_details_page.dart';
import 'package:star_kids_mobile/features/news/presentation/widgets/home_news_section.dart';

import '../../../../helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => NewsFeedController.clearCache());

  testWidgets('does not show a misleading all-news action', (tester) async {
    final controller = NewsFeedController(
      repository: _FakeNewsRepository(),
      pageSize: 1,
    );

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(body: HomeNewsSection(newsController: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Новости'), findsOneWidget);
    expect(find.text('Все новости'), findsNothing);
    expect(find.text('Тестовая новость'), findsOneWidget);
  });

  testWidgets('news card still opens the existing details route', (
    tester,
  ) async {
    final controller = NewsFeedController(
      repository: _FakeNewsRepository(),
      pageSize: 1,
    );

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(body: HomeNewsSection(newsController: controller)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тестовая новость'));
    await tester.pumpAndSettle();

    expect(find.byType(NewsDetailsPage), findsOneWidget);
  });
}

class _FakeNewsRepository implements NewsRepository {
  static final _item = NewsItem(
    id: 'news-1',
    title: 'Тестовая новость',
    imageUrl: '',
    description: 'Описание новости',
    createdAt: DateTime(2026, 9, 1),
  );

  @override
  Future<NewsItem> getNewsDetails(String newsId) async => _item;

  @override
  Future<List<NewsItem>> listNotificationHistory({
    required int limit,
    required int offset,
  }) async => const [];

  @override
  Future<List<NewsItem>> listPromotedNews({
    required int limit,
    required int offset,
  }) async => [_item];

  @override
  Future<void> trackNewsEvent({
    required String newsId,
    required NewsEventType eventType,
  }) async {}
}
