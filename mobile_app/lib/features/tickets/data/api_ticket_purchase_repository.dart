import '../../../core/api/api_client.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/mobile_auth_authorization.dart';
import '../../auth/data/mobile_auth_session_storage.dart';
import '../domain/ticket_purchase.dart';
import '../domain/ticket_purchase_repository.dart';
import 'ticket_purchase_api_models.dart';

class ApiTicketPurchaseRepository implements TicketPurchaseRepository {
  ApiTicketPurchaseRepository({
    required ApiClient apiClient,
    required MobileAuthSessionStorage sessionStorage,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage;

  final ApiClient _apiClient;
  final MobileAuthSessionStorage _sessionStorage;

  @override
  Future<Result<TicketPaymentStart>> startFreedomPayment({
    required List<TicketPaymentLineItemPayload> items,
    required DateTime? visitDate,
  }) async {
    final session = await _sessionStorage.readSession();
    if (session == null) {
      return const Failure<TicketPaymentStart>(
        'Войдите в аккаунт, чтобы купить билет.',
      );
    }

    try {
      final response = await _apiClient.postJson(
        '/payments/freedom/init',
        body: {
          'ticketItems': items
              .map(
                (item) => {
                  'ticketItemId': item.ticketItemId,
                  'quantity': item.quantity,
                },
              )
              .toList(),
          if (visitDate != null) 'visitDate': _formatDate(visitDate),
        },
        headers: buildMobileAuthAuthorizationHeader(session),
      );

      if (response.isSuccess && response.jsonBody != null) {
        return Success<TicketPaymentStart>(
          FreedomPaymentStartDto.fromJson(response.jsonBody!).toDomain(),
        );
      }

      return Failure<TicketPaymentStart>(
        _paymentErrorMessage(response),
      );
    } catch (_) {
      return const Failure<TicketPaymentStart>(
        'Не удалось начать оплату. Проверьте интернет и попробуйте снова.',
      );
    }
  }

  @override
  Future<Result<TicketPaymentStatus>> getPaymentStatus(String paymentId) async {
    final session = await _sessionStorage.readSession();
    if (session == null) {
      return const Failure<TicketPaymentStatus>(
        'Войдите в аккаунт, чтобы проверить оплату.',
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/payments/$paymentId',
        headers: buildMobileAuthAuthorizationHeader(session),
      );

      if (response.isSuccess && response.jsonBody != null) {
        return Success<TicketPaymentStatus>(
          TicketPaymentStatusDto.fromJson(response.jsonBody!).toDomain(),
        );
      }

      return Failure<TicketPaymentStatus>(
        _paymentErrorMessage(response),
      );
    } catch (_) {
      return const Failure<TicketPaymentStatus>(
        'Не удалось проверить статус оплаты. Попробуйте снова.',
      );
    }
  }

  @override
  Future<Result<List<PurchasedTicket>>> listPurchasedTickets() async {
    final session = await _sessionStorage.readSession();
    if (session == null) {
      return const Failure<List<PurchasedTicket>>(
        'Войдите в аккаунт, чтобы посмотреть билеты.',
      );
    }

    try {
      final response = await _apiClient.getJson(
        '/tickets/purchases',
        headers: buildMobileAuthAuthorizationHeader(session),
      );

      if (response.isSuccess && response.jsonBody != null) {
        return Success<List<PurchasedTicket>>(
          PurchasedTicketsDto.fromJson(response.jsonBody!).toDomain(),
        );
      }

      return Failure<List<PurchasedTicket>>(_paymentErrorMessage(response));
    } catch (_) {
      return const Failure<List<PurchasedTicket>>(
        'Не удалось загрузить билеты. Проверьте интернет и попробуйте снова.',
      );
    }
  }

  String _paymentErrorMessage(ApiClientResponse response) {
    if (response.statusCode == 401) {
      return 'Сессия истекла. Войдите в аккаунт еще раз.';
    }
    if (response.statusCode == 503) {
      return 'Платежный сервис временно недоступен.';
    }

    final errorBody = response.jsonBody?['error'];
    if (errorBody is Map<String, dynamic>) {
      final message = errorBody['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    return 'Не удалось выполнить платежное действие. Попробуйте снова.';
  }
}

String _formatDate(DateTime value) {
  final normalized = DateTime(value.year, value.month, value.day);
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}
