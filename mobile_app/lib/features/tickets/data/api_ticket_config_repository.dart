import '../../../core/api/api_client.dart';
import '../domain/branch_ticket_config.dart';
import '../domain/ticket_config_repository.dart';
import 'ticket_config_api_models.dart';

class ApiTicketConfigRepository implements TicketConfigRepository {
  ApiTicketConfigRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<BranchTicketConfig> getForBranch(String branchId) async {
    final response = await _apiClient.getJson('/branches/$branchId/tickets');
    final json = response.jsonBody;

    if (!response.isSuccess || json == null) {
      throw StateError('Ticket config is not available');
    }

    return BranchTicketConfigDto.fromJson(json).toDomain();
  }
}
