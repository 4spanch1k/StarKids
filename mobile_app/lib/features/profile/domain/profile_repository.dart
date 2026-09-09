import '../../../core/utils/result.dart';
import 'profile_update_payload.dart';
import 'user_profile.dart';

abstract interface class ProfileRepository {
  Future<Result<UserProfile>> fetchProfile();

  Future<Result<UserProfile>> updateProfile(ProfileUpdatePayload payload);

  Future<Result<UserProfile>> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  });

  Future<Result<void>> deleteAvatar();
}
