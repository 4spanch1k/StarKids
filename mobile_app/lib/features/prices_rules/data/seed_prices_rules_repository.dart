import '../domain/branch_prices_rules.dart';
import '../domain/prices_rules_repository.dart';
import 'prices_rules_seed_data.dart';

class SeedPricesRulesRepository implements PricesRulesRepository {
  const SeedPricesRulesRepository();

  @override
  Future<BranchPricesRules> getForBranch(String branchId) async {
    return pricesRulesSeedData.firstWhere(
      (item) => item.branchId == branchId,
      orElse: () => pricesRulesSeedData.first,
    );
  }
}
