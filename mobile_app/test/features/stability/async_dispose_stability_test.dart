import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/birthdays/domain/birthday_package.dart';
import 'package:star_kids_mobile/features/birthdays/domain/birthday_package_repository.dart';
import 'package:star_kids_mobile/features/news/domain/news_item.dart';
import 'package:star_kids_mobile/features/news/domain/news_repository.dart';
import 'package:star_kids_mobile/features/news/presentation/controllers/news_feed_controller.dart';
import 'package:star_kids_mobile/features/requests/domain/birthday_request_payload.dart';
import 'package:star_kids_mobile/features/requests/domain/birthday_request_repository.dart';
import 'package:star_kids_mobile/features/requests/domain/birthday_request_submission.dart';
import 'package:star_kids_mobile/features/requests/presentation/controllers/birthday_request_form_controller.dart';

void main() {
  test('news refresh may finish safely after its screen is disposed', () async {
    final completer = Completer<List<NewsItem>>();
    final controller = NewsFeedController(
      repository: _DeferredNewsRepository(completer),
    );

    final operation = controller.forceRefresh();
    controller.dispose();
    completer.complete(const []);

    await expectLater(operation, completes);
  });

  test('package hydration does not touch disposed text controllers', () async {
    final completer = Completer<BirthdayPackage?>();
    final controller = BirthdayRequestFormController(
      repository: const _UnusedBirthdayRequestRepository(),
      packageRepository: _DeferredPackageRepository(completer),
      initialPackageId: 'package-1',
    );

    controller.dispose();
    completer.complete(
      const BirthdayPackage(
        id: 'package-1',
        name: 'Family',
        priceLabel: '10 000 тг',
        guestLabel: '10 гостей',
        description: '',
        highlights: [],
        imagePath: '',
      ),
    );

    await Future<void>.delayed(Duration.zero);
  });
}

class _DeferredNewsRepository implements NewsRepository {
  const _DeferredNewsRepository(this.completer);

  final Completer<List<NewsItem>> completer;

  @override
  Future<List<NewsItem>> listPromotedNews({
    required int limit,
    required int offset,
  }) =>
      completer.future;

  @override
  Future<NewsItem> getNewsDetails(String newsId) => throw UnimplementedError();

  @override
  Future<List<NewsItem>> listNotificationHistory({
    required int limit,
    required int offset,
  }) =>
      completer.future;

  @override
  Future<void> trackNewsEvent({
    required String newsId,
    required NewsEventType eventType,
  }) async {}
}

class _DeferredPackageRepository implements BirthdayPackageRepository {
  const _DeferredPackageRepository(this.completer);

  final Completer<BirthdayPackage?> completer;

  @override
  Future<BirthdayPackage?> getPackageById(String packageId) => completer.future;

  @override
  Future<List<BirthdayPackage>> listPackages({String? branchId}) async => [];
}

class _UnusedBirthdayRequestRepository implements BirthdayRequestRepository {
  const _UnusedBirthdayRequestRepository();

  @override
  Future<Result<BirthdayRequestSubmission>> submitBirthdayRequest(
    BirthdayRequestPayload payload,
  ) =>
      throw UnimplementedError();
}
