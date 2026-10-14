import 'branch_menu.dart';

abstract interface class MenuRepository {
  Future<BranchMenu> getForBranch(String branchId);
}
