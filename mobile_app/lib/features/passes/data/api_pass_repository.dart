import '../../../core/api/api_client.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/mobile_auth_authorization.dart';
import '../../auth/data/mobile_auth_session_storage.dart';
import '../domain/pass.dart';
import '../domain/pass_repository.dart';
import 'pass_api_models.dart';

class ApiPassRepository implements PassRepository {
  ApiPassRepository({
    required ApiClient apiClient,
    required MobileAuthSessionStorage sessionStorage,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage;

  final ApiClient _apiClient;
  final MobileAuthSessionStorage _sessionStorage;

  @override
  Future<Result<List<PassPlan>>> listPlans({String? branchId}) async {
    final session = await _sessionStorage.readSession();
    if (session == null) return const Failure('Войдите в аккаунт.');
    try {
      final suffix = branchId == null
          ? ''
          : '?branchId=${Uri.encodeQueryComponent(branchId)}';
      final response = await _apiClient.getJson(
        '/passes/plans$suffix',
        headers: buildMobileAuthAuthorizationHeader(session),
      );
      if (!response.isSuccess || response.jsonListBody == null) {
        return Failure(_errorMessage(response));
      }
      return Success(response.jsonListBody!
          .whereType<Map<String, dynamic>>()
          .map((json) => PassPlanDto.fromJson(json).toDomain())
          .where((plan) => plan.isActive)
          .toList(growable: false));
    } catch (_) {
      return const Failure('Не удалось загрузить абонементы.');
    }
  }

  @override
  Future<Result<List<CustomerPass>>> listPasses() async {
    final session = await _sessionStorage.readSession();
    if (session == null) return const Failure('Войдите в аккаунт.');
    try {
      final response = await _apiClient.getJson(
        '/passes',
        headers: buildMobileAuthAuthorizationHeader(session),
      );
      if (!response.isSuccess || response.jsonBody == null) {
        return Failure(_errorMessage(response));
      }
      final items = response.jsonBody!['items'] as List<dynamic>? ?? const [];
      return Success(items
          .whereType<Map<String, dynamic>>()
          .map((json) => CustomerPassDto.fromJson(json).toDomain())
          .toList(growable: false));
    } catch (_) {
      return const Failure('Не удалось загрузить абонементы.');
    }
  }

  @override
  Future<Result<CustomerPass>> getPass(String passId) async {
    return _getPass('/passes/$passId');
  }

  @override
  Future<Result<String>> getPassQrPayload(String passId) async {
    final session = await _sessionStorage.readSession();
    if (session == null) return const Failure('Войдите в аккаунт.');
    try {
      final response = await _apiClient.getJson(
        '/passes/$passId/qr',
        headers: buildMobileAuthAuthorizationHeader(session),
      );
      final payload = response.jsonBody?['qrPayload'];
      if (!response.isSuccess || payload is! String || payload.isEmpty) {
        return Failure(_errorMessage(response));
      }
      return Success(payload);
    } catch (_) {
      return const Failure('Не удалось загрузить QR-код абонемента.');
    }
  }

  @override
  Future<Result<PassQuote>> quote({
    required String childId,
    required String passPlanId,
    required String branchId,
  }) async {
    final session = await _sessionStorage.readSession();
    if (session == null) return const Failure('Войдите в аккаунт.');
    try {
      final response = await _apiClient.postJson(
        '/passes/freedom/quote',
        body: {
          'childId': childId,
          'passPlanId': passPlanId,
          'branchId': branchId
        },
        headers: buildMobileAuthAuthorizationHeader(session),
      );
      if (!response.isSuccess || response.jsonBody == null) {
        return Failure(_errorMessage(response));
      }
      return Success(PassQuoteDto.fromJson(response.jsonBody!).toDomain());
    } catch (_) {
      return const Failure('Не удалось рассчитать стоимость абонемента.');
    }
  }

  @override
  Future<Result<PassPaymentStart>> startPayment({
    required String childId,
    required String passPlanId,
    required String branchId,
    required String idempotencyKey,
  }) async {
    final session = await _sessionStorage.readSession();
    if (session == null) return const Failure('Войдите в аккаунт.');
    try {
      final response = await _apiClient.postJson(
        '/passes/freedom/init',
        body: {
          'childId': childId,
          'passPlanId': passPlanId,
          'branchId': branchId,
          'idempotencyKey': idempotencyKey,
        },
        headers: buildMobileAuthAuthorizationHeader(session),
      );
      if (!response.isSuccess || response.jsonBody == null) {
        return Failure(_errorMessage(response));
      }
      return Success(passPaymentStartFromJson(response.jsonBody!));
    } catch (_) {
      return const Failure('Не удалось начать оплату. Попробуйте ещё раз.');
    }
  }

  Future<Result<CustomerPass>> _getPass(String path) async {
    final session = await _sessionStorage.readSession();
    if (session == null) return const Failure('Войдите в аккаунт.');
    try {
      final response = await _apiClient.getJson(
        path,
        headers: buildMobileAuthAuthorizationHeader(session),
      );
      if (!response.isSuccess || response.jsonBody == null) {
        return Failure(_errorMessage(response));
      }
      return Success(CustomerPassDto.fromJson(response.jsonBody!).toDomain());
    } catch (_) {
      return const Failure('Не удалось загрузить абонемент.');
    }
  }

  String _errorMessage(ApiClientResponse response) {
    if (response.statusCode == 401) return 'Сессия истекла. Войдите снова.';
    if (response.statusCode == 404) return 'Абонемент не найден.';
    final error = response.jsonBody?['error'];
    if (error is Map<String, dynamic> && error['message'] is String) {
      return error['message'] as String;
    }
    return 'Не удалось выполнить запрос. Попробуйте ещё раз.';
  }
}
