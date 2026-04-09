import '../../../core/api/api_client.dart';
import '../domain/branch_option.dart';
import '../domain/branch_repository.dart';
import 'branch_api_models.dart';
import 'seed_branch_repository.dart';

class ApiBranchRepository implements BranchRepository {
  ApiBranchRepository({
    required ApiClient apiClient,
    BranchRepository? fallbackRepository,
  })  : _apiClient = apiClient,
        _fallbackRepository =
            fallbackRepository ?? const SeedBranchRepository();

  final ApiClient _apiClient;
  final BranchRepository _fallbackRepository;

  @override
  Future<List<BranchOption>> listBranches() async {
    try {
      final response = await _apiClient.getJson('/branches');
      final jsonList = response.jsonListBody;

      if (!response.isSuccess || jsonList == null) {
        return _fallbackRepository.listBranches();
      }

      final summaries = jsonList
          .whereType<Map<String, dynamic>>()
          .map(BranchSummaryDto.fromJson)
          .toList();

      final branches = await Future.wait(
        summaries.map((summary) async {
          final detailedBranch = await _fetchBranchFromApi(summary.id);
          return detailedBranch ?? summary.toDomain();
        }),
      );

      return branches;
    } catch (_) {
      return _fallbackRepository.listBranches();
    }
  }

  @override
  Future<BranchOption> getBranch(String branchIdOrSlug) async {
    final branch = await _fetchBranchFromApi(branchIdOrSlug);
    if (branch != null) {
      return branch;
    }

    return _fallbackRepository.getBranch(branchIdOrSlug);
  }

  Future<BranchOption?> _fetchBranchFromApi(String branchIdOrSlug) async {
    try {
      final response = await _apiClient.getJson('/branches/$branchIdOrSlug');
      final json = response.jsonBody;

      if (!response.isSuccess || json == null) {
        return null;
      }

      return BranchDetailDto.fromJson(json).toDomain();
    } catch (_) {
      return null;
    }
  }
}
