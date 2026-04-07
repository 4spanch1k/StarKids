import 'branch_prices_rules.dart';

abstract interface class PricesRulesRepository {
  Future<BranchPricesRules> getForBranch(String branchId);
}
