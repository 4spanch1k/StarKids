import '../../../core/api/api_client.dart';
import '../../../core/utils/result.dart';
import '../domain/mobile_auth_repository.dart';
import '../domain/mobile_auth_session.dart';
import '../domain/otp_challenge.dart';
import 'mobile_auth_api_models.dart';
import 'mobile_auth_session_storage.dart';

class ApiMobileAuthRepository implements MobileAuthRepository {
  ApiMobileAuthRepository({
    required ApiClient apiClient,
    required MobileAuthSessionStorage sessionStorage,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage;

  final ApiClient _apiClient;
  final MobileAuthSessionStorage _sessionStorage;

  @override
  Future<Result<OtpChallenge>> requestOtp(String phone) async {
    try {
      final response = await _apiClient.postJson(
        '/auth/request-otp',
        body: {'phone': phone},
      );

      if (response.isSuccess && response.jsonBody != null) {
        final challenge = OtpRequestResponseDto.fromJson(
          response.jsonBody!,
        ).toDomain(
          phone: phone,
          requestedAt: DateTime.now(),
        );
        return Success<OtpChallenge>(challenge);
      }

      if (response.statusCode == 422) {
        return const Failure<OtpChallenge>(
          'Введите корректный номер телефона.',
        );
      }

      return const Failure<OtpChallenge>(
        'Не удалось отправить код. Проверьте интернет и попробуйте снова.',
      );
    } catch (_) {
      return const Failure<OtpChallenge>(
        'Не удалось отправить код. Проверьте интернет и попробуйте снова.',
      );
    }
  }

  @override
  Future<Result<MobileAuthSession>> verifyOtp({
    required String phone,
    required String code,
    required String verificationId,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/auth/verify-otp',
        body: {
          'phone': phone,
          'code': code,
          'verification_id': verificationId,
        },
      );

      if (response.isSuccess && response.jsonBody != null) {
        final session = TokenResponseDto.fromJson(
          response.jsonBody!,
        ).toDomain(
          phone: phone,
          verifiedAt: DateTime.now(),
        );
        await _sessionStorage.saveSession(session);
        return Success<MobileAuthSession>(session);
      }

      if (response.statusCode == 422 || response.statusCode == 401) {
        return const Failure<MobileAuthSession>(
          'Проверьте код и попробуйте еще раз.',
        );
      }

      return const Failure<MobileAuthSession>(
        'Не удалось подтвердить код. Попробуйте снова немного позже.',
      );
    } catch (_) {
      return const Failure<MobileAuthSession>(
        'Не удалось подтвердить код. Попробуйте снова немного позже.',
      );
    }
  }

  @override
  Future<MobileAuthSession?> restoreSession() {
    return _sessionStorage.readSession();
  }

  @override
  Future<void> clearSession() {
    return _sessionStorage.clearSession();
  }
}
