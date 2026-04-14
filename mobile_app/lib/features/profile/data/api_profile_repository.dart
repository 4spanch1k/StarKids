import '../../../core/api/api_client.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/mobile_auth_authorization.dart';
import '../../auth/data/mobile_auth_session_storage.dart';
import '../../auth/domain/mobile_auth_repository.dart';
import '../../auth/domain/mobile_auth_session.dart';
import '../domain/profile_repository.dart';
import '../domain/profile_update_payload.dart';
import '../domain/user_profile.dart';
import 'profile_api_models.dart';

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository({
    required ApiClient apiClient,
    required MobileAuthSessionStorage sessionStorage,
    required MobileAuthRepository authRepository,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage,
        _authRepository = authRepository;

  final ApiClient _apiClient;
  final MobileAuthSessionStorage _sessionStorage;
  final MobileAuthRepository _authRepository;

  static const _errorNoSession = 'Пользователь не авторизован.';
  static const _errorNetwork =
      'Не удалось загрузить профиль. Проверьте интернет и попробуйте снова.';
  static const _errorUpdate =
      'Не удалось обновить профиль. Проверьте интернет и попробуйте снова.';
  static const _errorAvatar =
      'Не удалось загрузить аватар. Проверьте интернет и попробуйте снова.';
  static const _errorDeleteAvatar =
      'Не удалось удалить аватар. Проверьте интернет и попробуйте снова.';

  @override
  Future<Result<UserProfile>> fetchProfile() async {
    return _performAuthorizedRequest(
      perform: (session) => _apiClient.getJson(
        '/me',
        headers: buildMobileAuthAuthorizationHeader(session),
      ),
      mapSuccess: (json) => UserProfileDto.fromJson(json).toDomain(),
      errorMessage: _errorNetwork,
    );
  }

  @override
  Future<Result<UserProfile>> updateProfile(ProfileUpdatePayload payload) async {
    final body = <String, dynamic>{};
    if (payload.firstName != null) body['firstName'] = payload.firstName;
    if (payload.lastName != null) body['lastName'] = payload.lastName;
    if (payload.email != null) body['email'] = payload.email;
    if (payload.childBirthDate != null) {
      final d = payload.childBirthDate!;
      body['childBirthDate'] =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    return _performAuthorizedRequest(
      perform: (session) => _apiClient.patchJson(
        '/me',
        body: body,
        headers: buildMobileAuthAuthorizationHeader(session),
      ),
      mapSuccess: (json) => UserProfileDto.fromJson(json).toDomain(),
      errorMessage: _errorUpdate,
    );
  }

  @override
  Future<Result<UserProfile>> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    // Backend returns {avatarUrl: "..."} for avatar upload (201).
    // We need the current profile to build an updated UserProfile.
    // First fetch the profile to get a base, then upload and merge.
    final profileResult = await fetchProfile();
    if (profileResult is Failure<UserProfile>) {
      return profileResult;
    }
    final baseProfile = (profileResult as Success<UserProfile>).data;

    return _performAuthorizedRequest<UserProfile>(
      perform: (session) => _apiClient.postMultipart(
        '/me/avatar',
        fieldName: 'file',
        bytes: bytes,
        filename: fileName,
        contentType: contentType,
        headers: buildMobileAuthAuthorizationHeader(session),
      ),
      mapSuccess: (json) {
        final avatarUrl = AvatarUploadResponseDto.fromJson(json).avatarUrl;
        return baseProfile.copyWith(avatarUrl: avatarUrl);
      },
      errorMessage: _errorAvatar,
    );
  }

  @override
  Future<Result<void>> deleteAvatar() async {
    return _performAuthorizedRequest<void>(
      perform: (session) => _apiClient.deleteJson(
        '/me/avatar',
        headers: buildMobileAuthAuthorizationHeader(session),
      ),
      mapSuccess: (_) => null,
      errorMessage: _errorDeleteAvatar,
    );
  }

  Future<Result<T>> _performAuthorizedRequest<T>({
    required Future<ApiClientResponse> Function(MobileAuthSession) perform,
    required T Function(Map<String, dynamic>) mapSuccess,
    required String errorMessage,
  }) async {
    try {
      final storedSession = await _sessionStorage.readSession();
      if (storedSession == null) {
        return Failure<T>(_errorNoSession);
      }

      final initialResponse = await perform(storedSession);
      if (initialResponse.isSuccess) {
        final json = initialResponse.jsonBody ?? <String, dynamic>{};
        return Success<T>(mapSuccess(json));
      }

      if (initialResponse.statusCode != 401) {
        return _extractErrorOrDefault<T>(initialResponse, errorMessage);
      }

      final syncResult = await _authRepository.syncSession(storedSession);
      if (syncResult is Failure<MobileAuthSession?>) {
        return Failure<T>(syncResult.message);
      }

      final refreshedSession = (syncResult as Success<MobileAuthSession?>).data;
      if (refreshedSession == null) {
        return Failure<T>(_errorNoSession);
      }

      final retryResponse = await perform(refreshedSession);
      if (retryResponse.isSuccess) {
        final json = retryResponse.jsonBody ?? <String, dynamic>{};
        return Success<T>(mapSuccess(json));
      }

      if (retryResponse.statusCode == 401) {
        return Failure<T>(_errorNoSession);
      }

      return _extractErrorOrDefault<T>(retryResponse, errorMessage);
    } catch (_) {
      return Failure<T>(errorMessage);
    }
  }

  Result<T> _extractErrorOrDefault<T>(
    ApiClientResponse response,
    String defaultMessage,
  ) {
    final body = response.jsonBody;
    if (body != null) {
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        final msg = error['message'] as String?;
        if (msg != null && msg.isNotEmpty) {
          return Failure<T>(msg);
        }
      }
    }
    return Failure<T>(defaultMessage);
  }
}
