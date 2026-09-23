import '../../../core/api/api_client.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/mobile_auth_authorization.dart';
import '../../auth/data/mobile_auth_session_storage.dart';
import '../domain/loyalty_account.dart';
import '../domain/loyalty_repository.dart';
import '../domain/loyalty_transaction.dart';

class ApiLoyaltyRepository implements LoyaltyRepository {
  ApiLoyaltyRepository({required this.apiClient, required this.sessionStorage});

  final ApiClient apiClient;
  final MobileAuthSessionStorage sessionStorage;

  @override
  Future<Result<LoyaltyAccount>> fetchAccount() async {
    final session = await sessionStorage.readSession();
    if (session == null) return const Failure('Пользователь не авторизован.');
    try {
      final response = await apiClient.getJson('/loyalty/account', headers: buildMobileAuthAuthorizationHeader(session));
      if (!response.isSuccess || response.jsonBody == null) return const Failure('Не удалось загрузить бонусный баланс.');
      return Success(LoyaltyAccount.fromJson(response.jsonBody!));
    } catch (_) {
      return const Failure('Не удалось загрузить бонусный баланс.');
    }
  }

  @override
  Future<Result<List<LoyaltyTransaction>>> fetchTransactions({int limit = 20, int offset = 0}) async {
    final session = await sessionStorage.readSession();
    if (session == null) return const Failure('Пользователь не авторизован.');
    try {
      final response = await apiClient.getJson('/loyalty/transactions?limit=$limit&offset=$offset', headers: buildMobileAuthAuthorizationHeader(session));
      final body = response.jsonBody;
      if (!response.isSuccess || body == null) return const Failure('Не удалось загрузить историю бонусов.');
      final items = (body['items'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>().map(LoyaltyTransaction.fromJson).toList(growable: false);
      return Success(items);
    } catch (_) {
      return const Failure('Не удалось загрузить историю бонусов.');
    }
  }
}
