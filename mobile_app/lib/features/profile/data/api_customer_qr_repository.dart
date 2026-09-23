import '../../../core/api/api_client.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/mobile_auth_authorization.dart';
import '../../auth/data/mobile_auth_session_storage.dart';
import '../../auth/domain/mobile_auth_repository.dart';
import '../../auth/domain/mobile_auth_session.dart';
import '../domain/customer_qr.dart';
import '../domain/customer_qr_repository.dart';

class ApiCustomerQrRepository implements CustomerQrRepository {
  ApiCustomerQrRepository({
    required ApiClient apiClient,
    required MobileAuthSessionStorage sessionStorage,
    required MobileAuthRepository authRepository,
  }) : _apiClient = apiClient,
       _sessionStorage = sessionStorage,
       _authRepository = authRepository;

  final ApiClient _apiClient;
  final MobileAuthSessionStorage _sessionStorage;
  final MobileAuthRepository _authRepository;

  @override
  Future<Result<CustomerQr>> fetchCustomerQr() async {
    final session = await _sessionStorage.readSession();
    if (session == null) {
      return const Failure<CustomerQr>('Пользователь не авторизован.');
    }

    final initial = await _request(session);
    if (initial.isSuccess) return _parse(initial);
    if (initial.statusCode != 401) {
      return Failure<CustomerQr>(_errorMessage(initial));
    }

    final synced = await _authRepository.syncSession(session);
    if (synced is Failure<MobileAuthSession?>) {
      return Failure<CustomerQr>(synced.message);
    }
    final refreshed = (synced as Success<MobileAuthSession?>).data;
    if (refreshed == null) {
      return const Failure<CustomerQr>(
        'Сессия истекла. Войдите в аккаунт еще раз.',
      );
    }
    final retry = await _request(refreshed);
    if (retry.isSuccess) return _parse(retry);
    return Failure<CustomerQr>(_errorMessage(retry));
  }

  Future<ApiClientResponse> _request(MobileAuthSession session) {
    return _apiClient.getJson(
      '/me/qr',
      headers: buildMobileAuthAuthorizationHeader(session),
    );
  }

  Result<CustomerQr> _parse(ApiClientResponse response) {
    final body = response.jsonBody;
    final payload = body?['qrPayload'];
    final expiresAtRaw = body?['expiresAt'];
    if (payload is! String || payload.isEmpty || expiresAtRaw is! String) {
      return const Failure<CustomerQr>('QR-код клиента недоступен.');
    }
    try {
      return Success<CustomerQr>(
        CustomerQr(
          qrPayload: payload,
          expiresAt: DateTime.parse(expiresAtRaw).toUtc(),
        ),
      );
    } catch (_) {
      return const Failure<CustomerQr>('QR-код клиента недоступен.');
    }
  }

  String _errorMessage(ApiClientResponse response) {
    if (response.statusCode == 401) {
      return 'Сессия истекла. Войдите в аккаунт еще раз.';
    }
    return 'Не удалось загрузить QR-код. Попробуйте еще раз.';
  }
}
