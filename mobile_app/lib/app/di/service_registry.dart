import '../../core/api/api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../features/birthdays/data/api_birthday_package_repository.dart';
import '../../features/birthdays/domain/birthday_package_repository.dart';
import '../../features/branches/data/api_branch_repository.dart';
import '../../features/branches/domain/branch_repository.dart';
import '../../features/contacts/data/api_contact_links_repository.dart';
import '../../features/contacts/domain/contact_links_repository.dart';
import '../../features/prices_rules/data/api_prices_rules_repository.dart';
import '../../features/prices_rules/domain/prices_rules_repository.dart';
import '../../features/promotions/data/api_promotion_repository.dart';
import '../../features/promotions/domain/promotion_repository.dart';
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
  static final BranchRepository branchRepository = ApiBranchRepository(
    apiClient: apiClient,
  );
  static final BirthdayPackageRepository birthdayPackageRepository =
      ApiBirthdayPackageRepository(
    apiClient: apiClient,
  );
  static final PromotionRepository promotionRepository = ApiPromotionRepository(
    apiClient: apiClient,
  );
  static final PricesRulesRepository pricesRulesRepository =
      ApiPricesRulesRepository(
    apiClient: apiClient,
  );
  static final ContactLinksRepository contactLinksRepository =
      ApiContactLinksRepository(
    apiClient: apiClient,
  );
  static final birthdayRequestRepository =
      AppEnvironment.useMockBirthdayRequests
          ? MockBirthdayRequestRepository()
          : ApiBirthdayRequestRepository(apiClient: apiClient);

  static Future<void> bootstrap() async {
    await selectedBranchController.load();
  }
}
