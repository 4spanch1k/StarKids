import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:star_kids_mobile/core/settings/app_settings_controller.dart';
import 'package:star_kids_mobile/core/storage/local_storage.dart';
import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/children/domain/child.dart';
import 'package:star_kids_mobile/features/children/domain/children_repository.dart';
import 'package:star_kids_mobile/features/children/presentation/controllers/children_controller.dart';
import 'package:star_kids_mobile/features/notifications/domain/notification_permission_status.dart';
import 'package:star_kids_mobile/features/notifications/domain/notification_settings_repository.dart';
import 'package:star_kids_mobile/features/notifications/presentation/controllers/mobile_notifications_controller.dart';
import 'package:star_kids_mobile/features/profile/domain/profile_repository.dart';
import 'package:star_kids_mobile/features/profile/domain/profile_update_payload.dart';
import 'package:star_kids_mobile/features/profile/domain/user_profile.dart';
import 'package:star_kids_mobile/features/profile/presentation/controllers/profile_controller.dart';
import 'package:star_kids_mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_item.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_repository.dart';
import 'package:star_kids_mobile/features/requests/domain/request_status.dart';
import 'package:star_kids_mobile/features/requests/domain/request_type.dart';

import '../../../../helpers/test_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfilePage', () {
    testWidgets(
        'success state renders user name, personal data section and request preview',
        (tester) async {
      const profile = UserProfile(
        id: 'user-1',
        firstName: 'Алима',
        lastName: 'Тест',
        email: 'alima@example.com',
      );

      final previewItem = RequestHistoryItem(
        id: 'req-1',
        type: RequestType.contact,
        status: RequestStatus.newRequest,
        createdAt: DateTime.parse('2026-04-10T10:00:00Z'),
      );

      final controller = ProfileController(
        profileRepository: _FakeProfileRepository(profile: profile),
        requestHistoryRepository: _FakeRequestHistoryRepository(
          items: [previewItem],
          total: 1,
        ),
      );

      final notificationsController = MobileNotificationsController(
        repository: const _FakeNotificationSettingsRepository(
          loadStatus: NotificationPermissionStatus.unknown,
        ),
      );

      final childrenController = ChildrenController(
        repository: _FakeChildrenRepository(children: const []),
      );

      final settingsController = AppSettingsController(
        localStorage: LocalStorage(),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ProfilePage(
            controller: controller,
            notificationsController: notificationsController,
            childrenControllerOverride: childrenController,
            settingsControllerOverride: settingsController,
            appVersionOverride: '1.0.0',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Алима Тест'), findsOneWidget);
      expect(find.text('Личные данные'), findsOneWidget);
      expect(find.text('Мои заявки'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Менеджеру'), findsOneWidget);
    });

    testWidgets('error state shows message and retry button', (tester) async {
      final controller = ProfileController(
        profileRepository: _FakeProfileRepository(
          failWith: 'Сервер недоступен.',
        ),
        requestHistoryRepository:
            _FakeRequestHistoryRepository(items: const [], total: 0),
      );

      final notificationsController = MobileNotificationsController(
        repository: const _FakeNotificationSettingsRepository(
          loadStatus: NotificationPermissionStatus.unknown,
        ),
      );

      final childrenController = ChildrenController(
        repository: _FakeChildrenRepository(children: const []),
      );

      final settingsController = AppSettingsController(
        localStorage: LocalStorage(),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ProfilePage(
            controller: controller,
            notificationsController: notificationsController,
            childrenControllerOverride: childrenController,
            settingsControllerOverride: settingsController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Не удалось загрузить профиль'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });
  });
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.profile, this.failWith});

  final UserProfile? profile;
  final String? failWith;

  @override
  Future<Result<UserProfile>> fetchProfile() async {
    if (failWith != null) return Failure<UserProfile>(failWith!);
    return Success<UserProfile>(profile!);
  }

  @override
  Future<Result<UserProfile>> updateProfile(
      ProfileUpdatePayload payload) async {
    return Success<UserProfile>(profile!);
  }

  @override
  Future<Result<UserProfile>> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    return Success<UserProfile>(profile!);
  }

  @override
  Future<Result<void>> deleteAvatar() async {
    return const Success<void>(null);
  }
}

class _FakeRequestHistoryRepository implements RequestHistoryRepository {
  _FakeRequestHistoryRepository({required this.items, required this.total});

  final List<RequestHistoryItem> items;
  final int total;

  @override
  Future<RequestHistoryFetchResult> fetchMyRequests() async {
    return RequestHistoryFetchSuccess(items: items, total: total);
  }
}

class _FakeNotificationSettingsRepository
    implements NotificationSettingsRepository {
  const _FakeNotificationSettingsRepository({required this.loadStatus});

  final NotificationPermissionStatus loadStatus;

  @override
  Future<NotificationPermissionStatus> loadPermissionStatus() async =>
      loadStatus;

  @override
  Future<bool> openSystemSettings() async => true;

  @override
  Future<NotificationPermissionStatus> requestPermission() async => loadStatus;
}

class _FakeChildrenRepository implements ChildrenRepository {
  _FakeChildrenRepository({required this.children});
  final List<Child> children;

  @override
  Future<Result<List<Child>>> fetchChildren() async =>
      Success<List<Child>>(children);

  @override
  Future<Result<Child>> createChild({
    required String name,
    required DateTime birthDate,
    required ChildGender gender,
  }) async =>
      const Failure<Child>('not implemented');

  @override
  Future<Result<Child>> updateChild({
    required String childId,
    String? name,
    DateTime? birthDate,
    ChildGender? gender,
  }) async =>
      const Failure<Child>('not implemented');

  @override
  Future<Result<void>> deleteChild(String childId) async =>
      const Success<void>(null);
}
