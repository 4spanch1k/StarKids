import '../../core/api/api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../features/requests/data/api_birthday_request_repository.dart';
import '../../features/branches/presentation/controllers/selected_branch_controller.dart';
import '../../features/requests/data/mock_birthday_request_repository.dart';
import '../config/app_environment.dart';

abstract final class ServiceRegistry {
  static final apiClient = ApiClient(baseUrl: AppEnvironment.apiBaseUrl);
  static final localStorage = LocalStorage();
  static final selectedBranchController = SelectedBranchController(
    localStorage: localStorage,
  );
  static final birthdayRequestRepository = AppEnvironment.useMockBirthdayRequests
      ? MockBirthdayRequestRepository()
      : ApiBirthdayRequestRepository(apiClient: apiClient);

  static Future<void> bootstrap() async {
    await selectedBranchController.load();
  }
}
