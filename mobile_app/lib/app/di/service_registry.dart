import '../../core/api/api_client.dart';
import '../../core/services/external_link_service.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/storage/local_storage.dart';
import '../../features/auth/data/api_mobile_auth_repository.dart';
import '../../features/auth/data/mobile_auth_session_storage.dart';
import '../../features/auth/domain/mobile_auth_repository.dart';
import '../../features/auth/presentation/controllers/mobile_auth_controller.dart';
import '../../features/birthdays/data/api_birthday_package_repository.dart';
import '../../features/birthdays/domain/birthday_package_repository.dart';
import '../../features/branches/data/api_branch_repository.dart';
import '../../features/branches/domain/branch_repository.dart';
import '../../features/branches/presentation/controllers/selected_branch_controller.dart';
import '../../features/children/data/api_children_repository.dart';
import '../../features/children/domain/children_repository.dart';
import '../../features/children/presentation/controllers/children_controller.dart';
import '../../features/content/data/api_public_content_repository.dart';
import '../../features/content/domain/public_content_repository.dart';
import '../../features/contacts/data/api_contact_links_repository.dart';
import '../../features/contacts/domain/contact_links_repository.dart';
import '../../features/menu/data/api_menu_repository.dart';
import '../../features/menu/domain/menu_repository.dart';
import '../../features/news/data/api_news_repository.dart';
import '../../features/news/domain/news_repository.dart';
import '../../features/notifications/data/api_notification_history_repository.dart';
import '../../features/notifications/data/api_push_token_repository.dart';
import '../../features/notifications/domain/notification_history_repository.dart';
import '../../features/notifications/data/device_notification_settings_repository.dart';
import '../../features/notifications/data/fcm_token_gateway.dart';
import '../../features/notifications/data/firebase_fcm_token_gateway.dart';
import '../../features/notifications/data/notification_permission_storage.dart';
import '../../features/notifications/data/permission_handler_notification_permission_gateway.dart';
import '../../features/notifications/domain/notification_settings_repository.dart';
import '../../features/notifications/domain/push_token_repository.dart';
import '../../features/notifications/presentation/controllers/mobile_notifications_controller.dart';
import '../../features/notifications/presentation/controllers/push_token_controller.dart';
import '../../features/promotions/data/api_promotion_repository.dart';
import '../../features/promotions/domain/promotion_repository.dart';
import '../../features/profile/data/api_profile_repository.dart';
import '../../features/profile/domain/profile_repository.dart';
import '../../features/profile/presentation/controllers/profile_controller.dart';
import '../../features/request_history/data/api_request_history_repository.dart';
import '../../features/request_history/domain/request_history_repository.dart';
import '../../features/requests/data/api_birthday_request_repository.dart';
import '../../features/requests/data/api_contact_request_repository.dart';
import '../../features/requests/data/mock_birthday_request_repository.dart';
import '../../features/requests/domain/contact_request_repository.dart';
import '../../features/tickets/data/api_ticket_config_repository.dart';
import '../../features/tickets/data/api_ticket_purchase_repository.dart';
import '../../features/tickets/domain/ticket_config_repository.dart';
import '../../features/tickets/domain/ticket_purchase_repository.dart';
import '../config/app_environment.dart';

typedef PaymentUrlLauncher = Future<bool> Function(String url);

abstract final class ServiceRegistry {
  static final apiClient = ApiClient(baseUrl: AppEnvironment.apiBaseUrl);
  static final localStorage = LocalStorage();
  static final appSettingsController =
      AppSettingsController(localStorage: localStorage);
  static final mobileAuthSessionStorage = MobileAuthSessionStorage();
  static final MobileAuthRepository mobileAuthRepository =
      ApiMobileAuthRepository(
    apiClient: apiClient,
    sessionStorage: mobileAuthSessionStorage,
  );
  static final mobileAuthController = MobileAuthController(
    repository: mobileAuthRepository,
  );
  static final BranchRepository branchRepository = ApiBranchRepository(
    apiClient: apiClient,
  );
  static final selectedBranchController = SelectedBranchController(
    localStorage: localStorage,
    branchRepository: branchRepository,
  );
  static final BirthdayPackageRepository birthdayPackageRepository =
      ApiBirthdayPackageRepository(apiClient: apiClient);
  static final PromotionRepository promotionRepository = ApiPromotionRepository(
    apiClient: apiClient,
  );
  static final MenuRepository menuRepository = ApiMenuRepository(
    apiClient: apiClient,
  );
  static final NewsRepository newsRepository = ApiNewsRepository(
    apiClient: apiClient,
  );
  static final NotificationHistoryRepository notificationHistoryRepository =
      ApiNotificationHistoryRepository(apiClient: apiClient);
  static TicketConfigRepository ticketConfigRepository =
      ApiTicketConfigRepository(apiClient: apiClient);
  static TicketPurchaseRepository ticketPurchaseRepository =
      ApiTicketPurchaseRepository(
    apiClient: apiClient,
    sessionStorage: mobileAuthSessionStorage,
  );
  static PaymentUrlLauncher paymentUrlLauncher = ExternalLinkService.openUrl;
  static final ContactLinksRepository contactLinksRepository =
      ApiContactLinksRepository(apiClient: apiClient);
  static final notificationPermissionStorage = NotificationPermissionStorage();
  static final notificationPermissionGateway =
      PermissionHandlerNotificationPermissionGateway();
  static final NotificationSettingsRepository notificationSettingsRepository =
      DeviceNotificationSettingsRepository(
    storage: notificationPermissionStorage,
    permissionGateway: notificationPermissionGateway,
  );
  static final mobileNotificationsController = MobileNotificationsController(
    repository: notificationSettingsRepository,
  );
  static final FcmTokenGateway fcmTokenGateway = FirebaseFcmTokenGateway();
  static final PushTokenRepository pushTokenRepository =
      ApiPushTokenRepository(apiClient: apiClient);
  static final pushTokenController = PushTokenController(
    authController: mobileAuthController,
    notificationSettingsRepository: notificationSettingsRepository,
    fcmTokenGateway: fcmTokenGateway,
    pushTokenRepository: pushTokenRepository,
  );
  static final PublicContentRepository publicContentRepository =
      ApiPublicContentRepository(apiClient: apiClient);
  static final RequestHistoryRepository requestHistoryRepository =
      ApiRequestHistoryRepository(
    apiClient: apiClient,
    sessionStorage: mobileAuthSessionStorage,
    authRepository: mobileAuthRepository,
  );
  static final ProfileRepository profileRepository = ApiProfileRepository(
    apiClient: apiClient,
    sessionStorage: mobileAuthSessionStorage,
    authRepository: mobileAuthRepository,
  );
  static final profileController = ProfileController(
    profileRepository: profileRepository,
    requestHistoryRepository: requestHistoryRepository,
  );
  static final ChildrenRepository childrenRepository = ApiChildrenRepository(
    apiClient: apiClient,
    sessionStorage: mobileAuthSessionStorage,
    authRepository: mobileAuthRepository,
  );
  static final childrenController = ChildrenController(
    repository: childrenRepository,
  );
  static final ContactRequestRepository contactRequestRepository =
      ApiContactRequestRepository(
    apiClient: apiClient,
    sessionStorage: mobileAuthSessionStorage,
  );
  static final birthdayRequestRepository =
      AppEnvironment.useMockBirthdayRequests
          ? MockBirthdayRequestRepository()
          : ApiBirthdayRequestRepository(
              apiClient: apiClient,
              sessionStorage: mobileAuthSessionStorage,
            );

  static Future<void> bootstrap() async {
    await appSettingsController.load();
    await mobileAuthController.bootstrap();
    await mobileNotificationsController.bootstrap();
    await selectedBranchController.load();
    await pushTokenController.bootstrap();
  }

  static void resetTicketConfigRepository() {
    ticketConfigRepository = ApiTicketConfigRepository(apiClient: apiClient);
  }

  static void resetTicketPurchaseRepository() {
    ticketPurchaseRepository = ApiTicketPurchaseRepository(
      apiClient: apiClient,
      sessionStorage: mobileAuthSessionStorage,
    );
  }

  static void resetPaymentUrlLauncher() {
    paymentUrlLauncher = ExternalLinkService.openUrl;
  }
}
