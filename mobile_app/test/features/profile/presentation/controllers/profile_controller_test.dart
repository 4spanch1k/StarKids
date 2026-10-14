import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/profile/domain/profile_repository.dart';
import 'package:star_kids_mobile/features/profile/domain/profile_update_payload.dart';
import 'package:star_kids_mobile/features/profile/domain/user_profile.dart';
import 'package:star_kids_mobile/features/profile/presentation/controllers/profile_controller.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_item.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_repository.dart';
import 'package:star_kids_mobile/features/requests/domain/request_status.dart';
import 'package:star_kids_mobile/features/requests/domain/request_type.dart';

void main() {
  test('hydrate applies onboarding profile before the next network refresh',
      () {
    final controller = ProfileController(
      profileRepository: _EmptyProfileRepository(),
      requestHistoryRepository: _EmptyRequestHistoryRepository(),
    );

    controller.hydrate(
      const UserProfile(
        id: 'user-onboarding',
        firstName: 'Алия',
        onboardingCompleted: true,
      ),
    );

    expect(controller.status, ProfileViewStatus.success);
    expect(controller.profile?.id, 'user-onboarding');
    expect(controller.firstNameDraft, 'Алия');
  });

  test(
    'authoritative reload replaces drafts when the account changes',
    () async {
      final repository = _SequenceProfileRepository([
        const UserProfile(
          id: 'user-a',
          firstName: 'Айжан',
          email: 'a@example.com',
        ),
        const UserProfile(
          id: 'user-b',
          firstName: 'Мадина',
          email: 'b@example.com',
        ),
      ]);
      final controller = ProfileController(
        profileRepository: repository,
        requestHistoryRepository: _EmptyRequestHistoryRepository(),
      );

      await controller.load();
      expect(controller.profile?.id, 'user-a');
      expect(controller.firstNameDraft, 'Айжан');
      expect(controller.emailDraft, 'a@example.com');

      await controller.load();
      expect(controller.profile?.id, 'user-b');
      expect(controller.firstNameDraft, 'Мадина');
      expect(controller.emailDraft, 'b@example.com');
    },
  );

  test('stale profile load cannot overwrite a newer load', () async {
    final repository = _DeferredProfileRepository();
    final controller = ProfileController(
      profileRepository: repository,
      requestHistoryRepository: _EmptyRequestHistoryRepository(),
    );

    final loadA = controller.load();
    final loadB = controller.load();

    repository.completeFetch(
      1,
      const UserProfile(
        id: 'user-b',
        firstName: 'Мадина',
        email: 'b@example.com',
      ),
    );
    await loadB;

    repository.completeFetch(
      0,
      const UserProfile(
        id: 'user-a',
        firstName: 'Айжан',
        email: 'a@example.com',
      ),
    );
    await loadA;

    expect(controller.profile?.id, 'user-b');
    expect(controller.firstNameDraft, 'Мадина');
    expect(controller.emailDraft, 'b@example.com');
  });

  test(
    'account reset clears profile state and blocks an in-flight old-account load',
    () async {
      final repository = _DeferredProfileRepository();
      final controller = ProfileController(
        profileRepository: repository,
        requestHistoryRepository: _EmptyRequestHistoryRepository(),
      );

      controller.hydrate(
        const UserProfile(
          id: 'user-a',
          firstName: 'Айжан',
          lastName: 'Старая',
          email: 'a@example.com',
        ),
      );
      final staleLoad = controller.load();

      controller.resetForAccountChange();

      expect(controller.profile, isNull);
      expect(controller.firstNameDraft, isEmpty);
      expect(controller.lastNameDraft, isEmpty);
      expect(controller.emailDraft, isEmpty);
      expect(controller.previewRequests, isEmpty);
      expect(controller.totalRequests, 0);
      expect(controller.status, ProfileViewStatus.loading);
      expect(controller.requestsStatus, ProfileRequestsStatus.loading);

      repository.completeFetch(
        0,
        const UserProfile(id: 'user-a', firstName: 'Старые данные'),
      );
      await staleLoad;

      expect(controller.profile, isNull);
      expect(controller.firstNameDraft, isEmpty);
    },
  );

  test('stale request preview cannot overwrite a newer account preview',
      () async {
    final profileRepository = _SequenceProfileRepository([
      const UserProfile(id: 'user-a', firstName: 'Айжан'),
      const UserProfile(id: 'user-b', firstName: 'Мадина'),
    ]);
    final requestRepository = _DeferredRequestHistoryRepository();
    final controller = ProfileController(
      profileRepository: profileRepository,
      requestHistoryRepository: requestRepository,
    );

    final loadA = controller.load();
    await _settle();
    expect(requestRepository.fetches, hasLength(1));

    final loadB = controller.load();
    await _settle();
    expect(requestRepository.fetches, hasLength(2));

    requestRepository.complete(
      1,
      _request('request-b'),
    );
    await loadB;

    requestRepository.complete(
      0,
      _request('request-a'),
    );
    await loadA;

    expect(controller.previewRequests.map((item) => item.id), ['request-b']);
  });
}

RequestHistoryItem _request(String id) => RequestHistoryItem(
      id: id,
      type: RequestType.birthdayRequest,
      status: RequestStatus.newRequest,
      createdAt: DateTime.utc(2026, 1, 1),
    );

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _SequenceProfileRepository implements ProfileRepository {
  _SequenceProfileRepository(this._profiles);

  final List<UserProfile> _profiles;
  var _index = 0;

  @override
  Future<Result<UserProfile>> fetchProfile() async {
    final profile =
        _profiles[_index < _profiles.length ? _index : _profiles.length - 1];
    _index += 1;
    return Success<UserProfile>(profile);
  }

  @override
  Future<Result<UserProfile>> updateProfile(
    ProfileUpdatePayload payload,
  ) async =>
      fetchProfile();

  @override
  Future<Result<UserProfile>> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async =>
      fetchProfile();

  @override
  Future<Result<void>> deleteAvatar() async => const Success<void>(null);
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

class _DeferredProfileRepository implements ProfileRepository {
  final List<Completer<Result<UserProfile>>> fetches = [];

  void completeFetch(int index, UserProfile profile) {
    fetches[index].complete(Success<UserProfile>(profile));
  }

  @override
  Future<Result<UserProfile>> fetchProfile() {
    final completer = Completer<Result<UserProfile>>();
    fetches.add(completer);
    return completer.future;
  }

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

class _DeferredRequestHistoryRepository implements RequestHistoryRepository {
  final List<Completer<RequestHistoryFetchResult>> fetches = [];

  void complete(int index, RequestHistoryItem item) {
    fetches[index].complete(
      RequestHistoryFetchSuccess(items: [item], total: 1),
    );
  }

  @override
  Future<RequestHistoryFetchResult> fetchMyRequests() {
    final completer = Completer<RequestHistoryFetchResult>();
    fetches.add(completer);
    return completer.future;
  }
}

class _EmptyRequestHistoryRepository implements RequestHistoryRepository {
  @override
  Future<RequestHistoryFetchResult> fetchMyRequests() async =>
      const RequestHistoryFetchSuccess(items: <RequestHistoryItem>[], total: 0);
}
