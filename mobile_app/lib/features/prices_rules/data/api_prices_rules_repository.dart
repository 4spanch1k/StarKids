import '../../../core/api/api_client.dart';
import '../domain/branch_prices_rules.dart';
import '../domain/prices_rules_repository.dart';
import 'prices_rules_api_models.dart';

class ApiPricesRulesRepository implements PricesRulesRepository {
  ApiPricesRulesRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<BranchPricesRules> getForBranch(String branchId) async {
    final response =
        await _apiClient.getJson('/branches/$branchId/prices-rules');
    final json = response.jsonBody;

    if (!response.isSuccess || json == null) {
      throw StateError('Prices and rules are not available');
    }

    return BranchPricesRulesDto.fromJson(json).toDomain();
  }
}
