import '../../../core/api/api_client.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/mobile_auth_authorization.dart';
import '../../auth/data/mobile_auth_session_storage.dart';
import '../../auth/domain/mobile_auth_repository.dart';
import '../../auth/domain/mobile_auth_session.dart';
import '../domain/child.dart';
import '../domain/children_repository.dart';
import 'children_api_models.dart';

class ApiChildrenRepository implements ChildrenRepository {
  ApiChildrenRepository({
    required ApiClient apiClient,
    required MobileAuthSessionStorage sessionStorage,
    required MobileAuthRepository authRepository,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage,
        _authRepository = authRepository;

  final ApiClient _apiClient;
  final MobileAuthSessionStorage _sessionStorage;
  final MobileAuthRepository _authRepository;

  static const _errNoSession = 'Пользователь не авторизован.';
  static const _errFetch =
      'Не удалось загрузить детей. Проверьте интернет и попробуйте снова.';
  static const _errSave =
      'Не удалось сохранить. Проверьте интернет и попробуйте снова.';
  static const _errDelete =
      'Не удалось удалить. Проверьте интернет и попробуйте снова.';

  @override
  Future<Result<List<Child>>> fetchChildren() async {
    return _authorized(
      perform: (s) => _apiClient.getJson(
        '/me/children',
        headers: buildMobileAuthAuthorizationHeader(s),
      ),
      map: (json) => ChildListDto.fromJson(json).toDomain(),
      error: _errFetch,
    );
  }

  @override
  Future<Result<Child>> createChild({
    required String name,
    required DateTime birthDate,
    required ChildGender gender,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'birthDate': _formatDate(birthDate),
      'gender': gender == ChildGender.female ? 'female' : 'male',
    };
    return _authorized(
      perform: (s) => _apiClient.postJson(
        '/me/children',
        body: body,
        headers: buildMobileAuthAuthorizationHeader(s),
      ),
      map: (json) => ChildDto.fromJson(json).toDomain(),
      error: _errSave,
    );
  }

  @override
  Future<Result<Child>> updateChild({
    required String childId,
    String? name,
    DateTime? birthDate,
    ChildGender? gender,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (birthDate != null) body['birthDate'] = _formatDate(birthDate);
    if (gender != null) {
      body['gender'] = gender == ChildGender.female ? 'female' : 'male';
    }
    return _authorized(
      perform: (s) => _apiClient.patchJson(
        '/me/children/$childId',
        body: body,
        headers: buildMobileAuthAuthorizationHeader(s),
      ),
      map: (json) => ChildDto.fromJson(json).toDomain(),
      error: _errSave,
    );
  }

  @override
  Future<Result<void>> deleteChild(String childId) async {
    return _authorized(
      perform: (s) => _apiClient.deleteJson(
        '/me/children/$childId',
        headers: buildMobileAuthAuthorizationHeader(s),
      ),
      map: (_) => null,
      error: _errDelete,
    );
  }

  // ─── Auth-retry helper ────────────────────────────────────────────────────

  Future<Result<T>> _authorized<T>({
    required Future<ApiClientResponse> Function(MobileAuthSession) perform,
    required T Function(Map<String, dynamic>) map,
    required String error,
  }) async {
    try {
      final stored = await _sessionStorage.readSession();
      if (stored == null) return Failure<T>(_errNoSession);

      final response = await perform(stored);
      if (response.isSuccess) {
        final json = response.jsonBody ?? <String, dynamic>{};
        return Success<T>(map(json));
      }

      if (response.statusCode != 401) {
        return _errorFrom<T>(response, error);
      }

      final sync = await _authRepository.syncSession(stored);
      if (sync is Failure<MobileAuthSession?>) {
        return Failure<T>(sync.message);
      }
      final refreshed = (sync as Success<MobileAuthSession?>).data;
      if (refreshed == null) return Failure<T>(_errNoSession);

      final retry = await perform(refreshed);
      if (retry.isSuccess) {
        final json = retry.jsonBody ?? <String, dynamic>{};
        return Success<T>(map(json));
      }
      if (retry.statusCode == 401) return Failure<T>(_errNoSession);
      return _errorFrom<T>(retry, error);
    } catch (_) {
      return Failure<T>(error);
    }
  }

  Result<T> _errorFrom<T>(ApiClientResponse response, String fallback) {
    final body = response.jsonBody;
    if (body != null) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        final msg = err['message'] as String?;
        if (msg != null && msg.isNotEmpty) return Failure<T>(msg);
      }
    }
    return Failure<T>(fallback);
  }

  String _formatDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
