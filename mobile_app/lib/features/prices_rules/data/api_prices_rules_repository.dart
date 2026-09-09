import '../../../core/api/api_client.dart';
import '../../../app/config/app_environment.dart';
import '../domain/branch_prices_rules.dart';
import '../domain/prices_rules_repository.dart';
import 'prices_rules_api_models.dart';
import 'seed_prices_rules_repository.dart';

class ApiPricesRulesRepository implements PricesRulesRepository {
  ApiPricesRulesRepository({
    required ApiClient apiClient,
    PricesRulesRepository? fallbackRepository,
  }) : _apiClient = apiClient,
       _fallbackRepository =
           fallbackRepository ?? const SeedPricesRulesRepository();

  final ApiClient _apiClient;
  final PricesRulesRepository _fallbackRepository;

  @override
  Future<BranchPricesRules> getForBranch(String branchId) async {
    try {
      final response = await _apiClient.getJson(
        '/branches/$branchId/prices-rules',
      );
      final json = response.jsonBody;

      if (!response.isSuccess || json == null) {
        return _fallbackOrThrow(branchId);
      }

      return BranchPricesRulesDto.fromJson(json).toDomain();
    } catch (_) {
      return _fallbackOrThrow(branchId);
    }
  }

  Future<BranchPricesRules> _fallbackOrThrow(String branchId) {
    if (AppEnvironment.allowsDevelopmentFixtures) {
      return _fallbackRepository.getForBranch(branchId);
    }
    throw StateError('Prices and rules are unavailable');
  }
}
