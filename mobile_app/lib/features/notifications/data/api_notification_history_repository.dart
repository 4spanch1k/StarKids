import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';

import '../../../core/api/api_client.dart';
import '../domain/app_notification.dart';
import '../domain/notification_history_repository.dart';
import 'notification_api_models.dart';

class ApiNotificationHistoryRepository
    implements NotificationHistoryRepository {
  ApiNotificationHistoryRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<AppNotification>> listNotifications({
    required int limit,
    required int offset,
  }) async {
    final response = await _guard(
      () => _apiClient.getJson('/notifications?limit=$limit&offset=$offset'),
    );
    final jsonList = response.jsonListBody;

    if (!response.isSuccess || jsonList == null) {
      throw const NotificationApiException(
        'Notification history is not available',
      );
    }

    return jsonList
        .whereType<Map<String, dynamic>>()
        .map(AppNotificationDto.fromJson)
        .map((item) => item.toDomain())
        .toList(growable: false);
  }

  Future<ApiClientResponse> _guard(
    Future<ApiClientResponse> Function() request,
  ) async {
    try {
      return await request();
    } on TimeoutException catch (error) {
      throw NotificationNetworkException('Request timed out', error);
    } on SocketException catch (error) {
      throw NotificationNetworkException('Network is unavailable', error);
    } on HttpException catch (error) {
      throw NotificationNetworkException('Network is unavailable', error);
    } on ClientException catch (error) {
      throw NotificationNetworkException('Network is unavailable', error);
    }
  }
}

class NotificationApiException implements Exception {
  const NotificationApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotificationNetworkException extends NotificationApiException {
  const NotificationNetworkException(
    super.message, [
    this.cause,
  ]);

  final Object? cause;
}
