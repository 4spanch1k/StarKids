import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/app/account_state_coordinator.dart';
import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/children/domain/child.dart';
import 'package:star_kids_mobile/features/children/domain/children_repository.dart';
import 'package:star_kids_mobile/features/children/presentation/controllers/children_controller.dart';
import 'package:star_kids_mobile/features/profile/domain/profile_repository.dart';
import 'package:star_kids_mobile/features/profile/domain/profile_update_payload.dart';
import 'package:star_kids_mobile/features/profile/domain/user_profile.dart';
import 'package:star_kids_mobile/features/profile/presentation/controllers/profile_controller.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_item.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_repository.dart';

void main() {
  test(
    'account switch clears shared family state before the next account loads',
    () {
      final auth = _IdentityNotifier('account-a');
      final profileController = _profileController();
      final childrenController = _childrenController();
      final coordinator = _coordinator(
        auth,
        profileController,
        childrenController,
      );

      profileController.hydrate(
        const UserProfile(id: 'account-a', firstName: 'Алия'),
      );
      childrenController.hydrate([_child('child-a', 'Алия')]);

      auth.setIdentity(null);
      expect(profileController.profile, isNull);
      expect(profileController.firstNameDraft, isEmpty);
      expect(childrenController.children, isEmpty);
      expect(childrenController.status, ChildrenStatus.loading);

      // A direct account switch is protected as well, even if logout/login
      // is observed as one auth lifecycle by the app.
      profileController.hydrate(
        const UserProfile(id: 'account-a', firstName: 'Алия'),
      );
      childrenController.hydrate([_child('child-a', 'Алия')]);
      auth.setIdentity('account-b');

      expect(profileController.profile, isNull);
      expect(childrenController.children, isEmpty);
      // RequestPage uses these shared controllers for birthday prefill; after
      // the switch there is no previous-account PII to prefill.
      expect(profileController.firstNameDraft, isEmpty);

      coordinator.dispose();
    },
  );

  test('same-account auth refresh keeps hydrated family state', () {
    final auth = _IdentityNotifier('account-a');
    final profileController = _profileController();
    final childrenController = _childrenController();
    final coordinator =
        _coordinator(auth, profileController, childrenController);

    profileController.hydrate(
      const UserProfile(id: 'account-a', firstName: 'Алия'),
    );
    childrenController.hydrate([_child('child-a', 'Алия')]);

    auth.setIdentity('account-a');

    expect(profileController.profile?.id, 'account-a');
    expect(profileController.firstNameDraft, 'Алия');
    expect(childrenController.children.single.id, 'child-a');
    expect(childrenController.status, ChildrenStatus.success);

    coordinator.dispose();
  });

  test('null to a new account also clears stale shared family state', () {
    final auth = _IdentityNotifier(null);
    final profileController = _profileController();
    final childrenController = _childrenController();
    final coordinator =
        _coordinator(auth, profileController, childrenController);

    profileController.hydrate(
      const UserProfile(id: 'stale-account', firstName: 'Старые данные'),
    );
    childrenController.hydrate([_child('stale-child', 'Старые данные')]);

    auth.setIdentity('account-b');

    expect(profileController.profile, isNull);
    expect(childrenController.children, isEmpty);
    coordinator.dispose();
  });
}

AccountStateCoordinator _coordinator(
  _IdentityNotifier auth,
  ProfileController profileController,
  ChildrenController childrenController,
) {
  return AccountStateCoordinator(
    authListenable: auth,
    readIdentity: () => auth.identity,
    profileController: profileController,
    childrenController: childrenController,
  );
}

ProfileController _profileController() => ProfileController(
      profileRepository: _EmptyProfileRepository(),
      requestHistoryRepository: _EmptyRequestHistoryRepository(),
    );

ChildrenController _childrenController() => ChildrenController(
      repository: _EmptyChildrenRepository(),
    );

Child _child(String id, String name) => Child(
      id: id,
      name: name,
      birthDate: DateTime(2020, 1, 2),
      gender: ChildGender.unspecified,
    );

class _IdentityNotifier extends ChangeNotifier {
  _IdentityNotifier(this.identity);

  String? identity;

  void setIdentity(String? next) {
    identity = next;
    notifyListeners();
  }
}

class _EmptyProfileRepository implements ProfileRepository {
  @override
  Future<Result<UserProfile>> fetchProfile() async =>
      const Failure<UserProfile>('not implemented');

  @override
  Future<Result<UserProfile>> updateProfile(
          ProfileUpdatePayload payload) async =>
      const Failure<UserProfile>('not implemented');

  @override
  Future<Result<UserProfile>> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async =>
      const Failure<UserProfile>('not implemented');

  @override
  Future<Result<void>> deleteAvatar() async => const Success<void>(null);
}

class _EmptyRequestHistoryRepository implements RequestHistoryRepository {
  @override
  Future<RequestHistoryFetchResult> fetchMyRequests() async =>
      const RequestHistoryFetchSuccess(items: <RequestHistoryItem>[], total: 0);
}

class _EmptyChildrenRepository implements ChildrenRepository {
  @override
  Future<Result<List<Child>>> fetchChildren() async =>
      const Success<List<Child>>([]);

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
      const Failure<void>('not implemented');
}
