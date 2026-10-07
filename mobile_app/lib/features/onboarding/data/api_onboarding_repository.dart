import '../../../core/api/api_client.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/mobile_auth_authorization.dart';
import '../../auth/data/mobile_auth_session_storage.dart';
import '../../auth/domain/mobile_auth_repository.dart';
import '../../auth/domain/mobile_auth_session.dart';
import '../../children/domain/child.dart';
import '../../profile/data/profile_api_models.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/onboarding_repository.dart';
import '../domain/onboarding_completion.dart';
import 'onboarding_api_models.dart';

class ApiOnboardingRepository implements OnboardingRepository {
  ApiOnboardingRepository({
    required ApiClient apiClient,
    required MobileAuthSessionStorage sessionStorage,
    required MobileAuthRepository authRepository,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage,
        _authRepository = authRepository;

  final ApiClient _apiClient;
  final MobileAuthSessionStorage _sessionStorage;
  final MobileAuthRepository _authRepository;

  @override
  Future<Result<UserProfile>> fetchProfile() async {
    return _authorized(
      perform: (session) => _apiClient.getJson(
        '/me',
        headers: buildMobileAuthAuthorizationHeader(session),
      ),
      map: (json) => UserProfileDto.fromJson(json).toDomain(),
      fallback: 'Не удалось загрузить профиль. Попробуйте снова.',
    );
  }

  @override
  Future<Result<OnboardingCompletion>> complete({
    required String firstName,
    required List<OnboardingChildDraft> children,
    required String privacyConsentVersion,
  }) async {
    final body = <String, dynamic>{
      'firstName': firstName.trim(),
      'children': [
        for (final child in children)
          {
            'name': child.name.trim(),
            'birthDate': _formatDate(child.birthDate),
            'gender': switch (child.gender) {
              ChildGender.male => 'male',
              ChildGender.female => 'female',
              ChildGender.unspecified => 'unspecified',
            },
          },
      ],
      'privacyConsentAccepted': true,
      'privacyConsentVersion': privacyConsentVersion,
    };
    return _authorized(
      perform: (session) => _apiClient.postJson(
        '/onboarding/complete',
        body: body,
        headers: buildMobileAuthAuthorizationHeader(session),
      ),
      map: (json) => OnboardingCompletionDto.fromJson(json).toDomain(),
      fallback: 'Не удалось сохранить профиль. Попробуйте снова.',
    );
  }

  Future<Result<T>> _authorized<T>({
    required Future<ApiClientResponse> Function(MobileAuthSession) perform,
    required T Function(Map<String, dynamic>) map,
    required String fallback,
  }) async {
    try {
      final stored = await _sessionStorage.readSession();
      if (stored == null) return Failure<T>('Пользователь не авторизован.');

      final response = await perform(stored);
      if (response.isSuccess) {
        return Success<T>(map(response.jsonBody ?? const {}));
      }
      if (response.statusCode == 401) {
        final sync = await _authRepository.syncSession(stored);
        if (sync is Success<MobileAuthSession?> && sync.data != null) {
          final retry = await perform(sync.data!);
          if (retry.isSuccess) {
            return Success<T>(map(retry.jsonBody ?? const {}));
          }
          return _error<T>(retry, fallback);
        }
      }
      return _error<T>(response, fallback);
    } catch (_) {
      return Failure<T>(fallback);
    }
  }

  Result<T> _error<T>(ApiClientResponse response, String fallback) {
    final error = response.jsonBody?['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'] as String?;
      if (message != null && message.isNotEmpty) return Failure<T>(message);
    }
    return Failure<T>(fallback);
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
