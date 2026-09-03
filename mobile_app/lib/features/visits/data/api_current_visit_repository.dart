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
