import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';

import '../../../core/api/api_client.dart';
import '../domain/news_item.dart';
import '../domain/news_repository.dart';
import 'news_api_models.dart';

class ApiNewsRepository implements NewsRepository {
  ApiNewsRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<NewsItem>> listNotificationHistory({
    required int limit,
    required int offset,
  }) async {
    return _loadList(
      '/notifications?limit=$limit&offset=$offset',
      unavailableMessage: 'Notification history is not available',
    );
  }

  @override
  Future<List<NewsItem>> listPromotedNews({
    required int limit,
    required int offset,
  }) async {
    return _loadList(
      '/news?limit=$limit&offset=$offset',
      unavailableMessage: 'News feed is not available',
    );
  }

  @override
  Future<NewsItem> getNewsDetails(String newsId) async {
    final response = await _guard(() => _apiClient.getJson('/news/$newsId'));
    final jsonBody = response.jsonBody;

    if (!response.isSuccess || jsonBody == null) {
      throw const NewsApiException('News details are not available');
    }

    return NewsItemDto.fromJson(jsonBody).toDomain();
  }

  @override
  Future<void> trackNewsEvent({
    required String newsId,
    required NewsEventType eventType,
  }) async {
    final response = await _guard(
      () => _apiClient.postJson(
        '/news/$newsId/events',
        body: {
          'event_type': eventType.name,
        },
      ),
    );

    if (!response.isSuccess) {
      throw const NewsApiException('News event is not available');
    }
  }

  Future<List<NewsItem>> _loadList(
    String path, {
    required String unavailableMessage,
  }) async {
    final response = await _guard(() => _apiClient.getJson(path));
    final jsonList = response.jsonListBody;

    if (!response.isSuccess || jsonList == null) {
      throw NewsApiException(unavailableMessage);
    }

    return jsonList
        .whereType<Map<String, dynamic>>()
        .map(NewsItemDto.fromJson)
        .map((item) => item.toDomain())
        .toList(growable: false);
  }

  Future<ApiClientResponse> _guard(
    Future<ApiClientResponse> Function() request,
  ) async {
    try {
      return await request();
    } on TimeoutException catch (error) {
      throw NewsNetworkException('Request timed out', error);
    } on SocketException catch (error) {
      throw NewsNetworkException('Network is unavailable', error);
    } on HttpException catch (error) {
      throw NewsNetworkException('Network is unavailable', error);
    } on ClientException catch (error) {
      throw NewsNetworkException('Network is unavailable', error);
    }
  }
}

class NewsApiException implements Exception {
  const NewsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NewsNetworkException extends NewsApiException {
  const NewsNetworkException(
    super.message, [
    this.cause,
  ]);

  final Object? cause;
}
