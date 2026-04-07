import 'branch_option.dart';

abstract interface class BranchRepository {
  Future<List<BranchOption>> listBranches();

  Future<BranchOption> getBranch(String branchIdOrSlug);
}
