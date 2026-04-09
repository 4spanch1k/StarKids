import 'branch_contact_links.dart';

abstract interface class ContactLinksRepository {
  Future<BranchContactLinks> getForBranch(String branchId);
}
