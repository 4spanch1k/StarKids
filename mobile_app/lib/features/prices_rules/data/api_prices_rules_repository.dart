import '../../../core/api/api_client.dart';
import '../domain/branch_prices_rules.dart';
import '../domain/prices_rules_repository.dart';
import 'prices_rules_api_models.dart';
import 'seed_prices_rules_repository.dart';

class ApiPricesRulesRepository implements PricesRulesRepository {
  ApiPricesRulesRepository({
    required ApiClient apiClient,
    PricesRulesRepository? fallbackRepository,
  })  : _apiClient = apiClient,
        _fallbackRepository =
            fallbackRepository ?? const SeedPricesRulesRepository();

  final ApiClient _apiClient;
  final PricesRulesRepository _fallbackRepository;

  @override
  Future<BranchPricesRules> getForBranch(String branchId) async {
    try {
      final response =
          await _apiClient.getJson('/branches/$branchId/prices-rules');
      final json = response.jsonBody;

      if (!response.isSuccess || json == null) {
        return _fallbackRepository.getForBranch(branchId);
      }

      return BranchPricesRulesDto.fromJson(json).toDomain();
    } catch (_) {
      return _fallbackRepository.getForBranch(branchId);
    }
  }
}
