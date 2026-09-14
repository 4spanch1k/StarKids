import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/profile/domain/profile_repository.dart';
import 'package:star_kids_mobile/features/profile/domain/profile_update_payload.dart';
import 'package:star_kids_mobile/features/profile/domain/user_profile.dart';
import 'package:star_kids_mobile/features/profile/presentation/controllers/profile_controller.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_item.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_repository.dart';

void main() {
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

class _EmptyRequestHistoryRepository implements RequestHistoryRepository {
  @override
  Future<RequestHistoryFetchResult> fetchMyRequests() async =>
      const RequestHistoryFetchSuccess(items: <RequestHistoryItem>[], total: 0);
}
