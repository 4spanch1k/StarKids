import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';

import '../../../core/api/api_client.dart';
import '../../auth/data/mobile_auth_authorization.dart';
import '../../auth/data/mobile_auth_session_storage.dart';
import '../domain/current_visit.dart';
import '../domain/current_visit_repository.dart';

class ApiCurrentVisitRepository implements CurrentVisitRepository {
  ApiCurrentVisitRepository(
      {required this.apiClient, required this.sessionStorage});

  final ApiClient apiClient;
  final MobileAuthSessionStorage sessionStorage;

  @override
  Future<CurrentVisit?> getCurrentVisit() async {
    final session = await sessionStorage.readSession();
    if (session == null) return null;
    try {
      final response = await apiClient.getJson(
        '/visits/current',
        headers: buildMobileAuthAuthorizationHeader(session),
      );
      if (!response.isSuccess) {
        throw const CurrentVisitApiException(
            'Не удалось проверить текущий визит.');
      }
      final json = response.jsonBody;
      if (json == null) return null;
      return CurrentVisit(
        visitId: json['visitId'] as String,
        branchId: json['branchId'] as String,
        branchName: json['branchName'] as String,
        status: json['status'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
      );
    } on TimeoutException catch (error) {
      throw CurrentVisitNetworkException(
          'Не удалось проверить текущий визит.', error);
    } on SocketException catch (error) {
      throw CurrentVisitNetworkException(
          'Не удалось проверить текущий визит.', error);
    } on HttpException catch (error) {
      throw CurrentVisitNetworkException(
          'Не удалось проверить текущий визит.', error);
    } on ClientException catch (error) {
      throw CurrentVisitNetworkException(
          'Не удалось проверить текущий визит.', error);
    }
  }

  @override
  Future<VisitHistory> getVisitHistory() async {
    final session = await sessionStorage.readSession();
    if (session == null) {
      throw const CurrentVisitApiException(
        'Войдите в аккаунт, чтобы посмотреть историю посещений.',
      );
    }
    try {
      final response = await apiClient.getJson(
        '/visits/history',
        headers: buildMobileAuthAuthorizationHeader(session),
      );
      if (!response.isSuccess || response.jsonBody == null) {
        throw const CurrentVisitApiException(
          'Не удалось загрузить историю посещений.',
        );
      }
      final json = response.jsonBody!;
      final rawItems = json['items'];
      final items = rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => VisitHistoryItem(
                  visitId: item['visitId'] as String,
                  branchId: item['branchId'] as String,
                  branchName: item['branchName'] as String,
                  startedAt: DateTime.parse(item['startedAt'] as String),
                  endedAt: item['endedAt'] == null
                      ? null
                      : DateTime.parse(item['endedAt'] as String),
                ),
              )
              .toList(growable: false)
          : const <VisitHistoryItem>[];
      return VisitHistory(
        visitCount: (json['visitCount'] as num?)?.toInt() ?? 0,
        firstVisitAt: _parseNullableDateTime(json['firstVisitAt']),
        lastVisitAt: _parseNullableDateTime(json['lastVisitAt']),
        items: items,
      );
    } on TimeoutException catch (error) {
      throw CurrentVisitNetworkException(
        'Не удалось загрузить историю посещений.',
        error,
      );
    } on SocketException catch (error) {
      throw CurrentVisitNetworkException(
        'Не удалось загрузить историю посещений.',
        error,
      );
    } on HttpException catch (error) {
      throw CurrentVisitNetworkException(
        'Не удалось загрузить историю посещений.',
        error,
      );
    } on ClientException catch (error) {
      throw CurrentVisitNetworkException(
        'Не удалось загрузить историю посещений.',
        error,
      );
    }
  }

  DateTime? _parseNullableDateTime(Object? value) {
    return value is String ? DateTime.tryParse(value) : null;
  }
}

class CurrentVisitApiException implements Exception {
  const CurrentVisitApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CurrentVisitNetworkException extends CurrentVisitApiException {
  const CurrentVisitNetworkException(super.message, [this.cause]);
  final Object? cause;
}
