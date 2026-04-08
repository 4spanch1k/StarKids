import '../../../core/api/api_client.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/mobile_auth_authorization.dart';
import '../../auth/data/mobile_auth_session_storage.dart';
import '../../auth/domain/mobile_auth_repository.dart';
import '../../auth/domain/mobile_auth_session.dart';
import '../domain/request_history_repository.dart';
import 'request_history_api_models.dart';

class ApiRequestHistoryRepository implements RequestHistoryRepository {
  ApiRequestHistoryRepository({
    required ApiClient apiClient,
    required MobileAuthSessionStorage sessionStorage,
    required MobileAuthRepository authRepository,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage,
        _authRepository = authRepository;

  final ApiClient _apiClient;
  final MobileAuthSessionStorage _sessionStorage;
  final MobileAuthRepository _authRepository;

  @override
  Future<RequestHistoryFetchResult> fetchMyRequests() async {
    try {
      final storedSession = await _sessionStorage.readSession();
      if (storedSession == null) {
        return const RequestHistoryFetchUnauthenticated();
      }

      final initialResponse = await _getHistoryResponse(storedSession);
      if (initialResponse.isSuccess && initialResponse.jsonBody != null) {
        return _mapSuccess(initialResponse.jsonBody!);
      }

      if (initialResponse.statusCode != 401) {
        return const RequestHistoryFetchFailure(
          'Не удалось загрузить заявки. Проверьте интернет и попробуйте снова.',
        );
      }

      final syncResult = await _authRepository.syncSession(storedSession);
      if (syncResult is Failure<MobileAuthSession?>) {
        return RequestHistoryFetchFailure(syncResult.message);
      }

      final refreshedSession = (syncResult as Success<MobileAuthSession?>).data;
      if (refreshedSession == null) {
        return const RequestHistoryFetchUnauthenticated();
      }

      final retryResponse = await _getHistoryResponse(refreshedSession);
      if (retryResponse.isSuccess && retryResponse.jsonBody != null) {
        return _mapSuccess(retryResponse.jsonBody!);
      }

      if (retryResponse.statusCode == 401) {
        return const RequestHistoryFetchUnauthenticated();
      }

      return const RequestHistoryFetchFailure(
        'Не удалось загрузить заявки. Проверьте интернет и попробуйте снова.',
      );
    } catch (_) {
      return const RequestHistoryFetchFailure(
        'Не удалось загрузить заявки. Проверьте интернет и попробуйте снова.',
      );
    }
  }

  Future<ApiClientResponse> _getHistoryResponse(MobileAuthSession session) {
    return _apiClient.getJson(
      '/me/requests',
      headers: buildMobileAuthAuthorizationHeader(session),
    );
  }

  RequestHistoryFetchSuccess _mapSuccess(Map<String, dynamic> json) {
    final dto = RequestHistoryListDto.fromJson(json);
    return RequestHistoryFetchSuccess(
      items: dto.items.map((item) => item.toDomain()).toList(growable: false),
      total: dto.total,
    );
  }
}
