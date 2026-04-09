import '../domain/branch_contact_links.dart';
import '../domain/contact_links_repository.dart';
import 'contact_link_seed_data.dart';

class SeedContactLinksRepository implements ContactLinksRepository {
  const SeedContactLinksRepository();

  @override
  Future<BranchContactLinks> getForBranch(String branchId) async {
    return contactLinkSeedData.firstWhere(
      (item) => item.branchId == branchId,
      orElse: () => contactLinkSeedData.first,
    );
  }
}
