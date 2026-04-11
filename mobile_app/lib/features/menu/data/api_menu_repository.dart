import '../../../core/api/api_client.dart';
import '../domain/branch_menu.dart';
import '../domain/menu_repository.dart';
import 'menu_api_models.dart';

class ApiMenuRepository implements MenuRepository {
  ApiMenuRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<BranchMenu> getForBranch(String branchId) async {
    final response = await _apiClient.getJson('/branches/$branchId/menu');
    final json = response.jsonBody;

    if (!response.isSuccess || json == null) {
      throw StateError('Menu is not available');
    }

    return BranchMenuDto.fromJson(json).toDomain();
  }
}
