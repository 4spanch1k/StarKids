import '../../../core/api/api_client.dart';
import '../domain/branch_contact_links.dart';
import '../domain/contact_links_repository.dart';
import 'contact_links_api_models.dart';

class ApiContactLinksRepository implements ContactLinksRepository {
  ApiContactLinksRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<BranchContactLinks> getForBranch(String branchId) async {
    final response = await _apiClient.getJson('/branches/$branchId/contacts');
    final json = response.jsonBody;

    if (!response.isSuccess || json == null) {
      throw StateError('Branch contacts are not available');
    }

    return BranchContactLinksDto.fromJson(json).toDomain();
  }
}
