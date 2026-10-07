import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';

import '../../../core/api/api_client.dart';
import '../../auth/data/mobile_auth_authorization.dart';
import '../../auth/data/mobile_auth_session_storage.dart';
import '../domain/issued_ticket.dart';
import '../domain/issued_ticket_repository.dart';
import 'issued_ticket_api_models.dart';

class ApiIssuedTicketRepository implements IssuedTicketRepository {
  ApiIssuedTicketRepository({
    required ApiClient apiClient,
    required MobileAuthSessionStorage sessionStorage,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage;

  final ApiClient _apiClient;
  final MobileAuthSessionStorage _sessionStorage;

  @override
  Future<List<IssuedTicket>> listIssuedTickets() async {
    final session = await _sessionStorage.readSession();
    if (session == null) {
      throw const IssuedTicketApiException(
        'Войдите в аккаунт, чтобы посмотреть билеты.',
      );
    }

    final response = await _guard(
      () => _apiClient.getJson(
        '/tickets',
        headers: buildMobileAuthAuthorizationHeader(session),
      ),
    );
    if (!response.isSuccess || response.jsonBody == null) {
      throw IssuedTicketApiException(_errorMessage(response));
    }
    return IssuedTicketsDto.fromJson(
      response.jsonBody!,
    ).items.map((item) => item.toDomain()).toList(growable: false);
  }

  @override
  Future<IssuedTicket> getIssuedTicket(String ticketId) async {
    final session = await _sessionStorage.readSession();
    if (session == null) {
      throw const IssuedTicketApiException(
        'Войдите в аккаунт, чтобы открыть билет.',
      );
    }

    final response = await _guard(
      () => _apiClient.getJson(
        '/tickets/$ticketId',
        headers: buildMobileAuthAuthorizationHeader(session),
      ),
    );
    if (!response.isSuccess || response.jsonBody == null) {
      throw IssuedTicketApiException(_errorMessage(response));
    }
    return IssuedTicketDto.fromJson(response.jsonBody!).toDomain();
  }

  @override
  Future<String> getIssuedTicketQrPayload(String ticketId) async {
    final session = await _sessionStorage.readSession();
    if (session == null) {
      throw const IssuedTicketApiException(
        'Войдите в аккаунт, чтобы открыть QR-код билета.',
      );
    }
    final response = await _guard(
      () => _apiClient.getJson(
        '/tickets/$ticketId/qr',
        headers: buildMobileAuthAuthorizationHeader(session),
      ),
    );
    if (!response.isSuccess || response.jsonBody == null) {
      throw IssuedTicketApiException(_errorMessage(response));
    }
    final payload = response.jsonBody!['qrPayload'];
    if (payload is! String || payload.isEmpty) {
      throw const IssuedTicketApiException('QR-код билета недоступен.');
    }
    return payload;
  }

  Future<ApiClientResponse> _guard(
    Future<ApiClientResponse> Function() request,
  ) async {
    try {
      return await request();
    } on TimeoutException catch (error) {
      throw IssuedTicketNetworkException('Не удалось загрузить билеты.', error);
    } on SocketException catch (error) {
      throw IssuedTicketNetworkException('Не удалось загрузить билеты.', error);
    } on HttpException catch (error) {
      throw IssuedTicketNetworkException('Не удалось загрузить билеты.', error);
    } on ClientException catch (error) {
      throw IssuedTicketNetworkException('Не удалось загрузить билеты.', error);
    }
  }

  String _errorMessage(ApiClientResponse response) {
    if (response.statusCode == 401) {
      return 'Сессия истекла. Войдите в аккаунт еще раз.';
    }
    if (response.statusCode == 404) {
      return 'Билет не найден.';
    }
    return 'Не удалось загрузить билеты. Попробуйте еще раз.';
  }
}

class IssuedTicketApiException implements Exception {
  const IssuedTicketApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class IssuedTicketNetworkException extends IssuedTicketApiException {
  const IssuedTicketNetworkException(super.message, [this.cause]);

  final Object? cause;
}
