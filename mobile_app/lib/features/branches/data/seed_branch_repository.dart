import '../domain/branch_option.dart';
import '../domain/branch_repository.dart';
import 'branch_seed_data.dart';

class SeedBranchRepository implements BranchRepository {
  const SeedBranchRepository();

  @override
  Future<List<BranchOption>> listBranches() async {
    return branchSeedData;
  }

  @override
  Future<BranchOption> getBranch(String branchIdOrSlug) async {
    return branchSeedData.firstWhere(
      (branch) => branch.id == branchIdOrSlug,
      orElse: () => getBranchById(branchIdOrSlug),
    );
  }
}
