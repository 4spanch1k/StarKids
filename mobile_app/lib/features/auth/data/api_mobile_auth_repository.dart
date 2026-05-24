import '../../../core/api/api_client.dart';
import '../../../core/utils/result.dart';
import '../domain/mobile_auth_repository.dart';
import '../domain/mobile_auth_session.dart';
import '../domain/mobile_auth_user.dart';
import '../domain/otp_challenge.dart';
import 'mobile_auth_authorization.dart';
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
  Future<Result<MobileAuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) {
    return _submitEmailAuth(
      path: '/auth/register',
      email: email,
      password: password,
      duplicateEmailMessage:
          'Эта электронная почта уже зарегистрирована. Войдите в аккаунт.',
      fallbackMessage:
          'Не удалось зарегистрироваться. Проверьте интернет и попробуйте снова.',
    );
  }

  @override
  Future<Result<MobileAuthSession>> loginWithEmail({
    required String email,
    required String password,
  }) {
    return _submitEmailAuth(
      path: '/auth/login',
      email: email,
      password: password,
      invalidCredentialsMessage: 'Проверьте почту и пароль.',
      fallbackMessage:
          'Не удалось войти. Проверьте интернет и попробуйте снова.',
    );
  }

  @override
  Future<Result<MobileAuthSession>> exchangeClerkSession({
    required String sessionToken,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/auth/clerk/exchange',
        body: {'session_token': sessionToken.trim()},
      );

      if (response.isSuccess) {
        final session = await _storeTokenResponse(response.jsonBody);
        if (session != null) {
          return Success<MobileAuthSession>(session);
        }

        return const Failure<MobileAuthSession>(
          'Не удалось завершить вход через Google. Попробуйте снова.',
        );
      }

      if (response.statusCode == 401) {
        return const Failure<MobileAuthSession>(
          'Не удалось подтвердить вход через Google. Попробуйте снова.',
        );
      }

      if (response.statusCode == 409) {
        return const Failure<MobileAuthSession>(
          'Этот Google аккаунт уже связан с другим профилем Star Kids.',
        );
      }

      if (response.statusCode == 422) {
        return const Failure<MobileAuthSession>(
          'Подтвердите email в Google и попробуйте снова.',
        );
      }

      return const Failure<MobileAuthSession>(
        'Не удалось войти через Google. Проверьте интернет и попробуйте снова.',
      );
    } catch (_) {
      return const Failure<MobileAuthSession>(
        'Не удалось войти через Google. Проверьте интернет и попробуйте снова.',
      );
    }
  }

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

      if (response.isSuccess) {
        final session = await _storeTokenResponse(response.jsonBody);
        if (session != null) {
          return Success<MobileAuthSession>(session);
        }

        return const Failure<MobileAuthSession>(
          'Не удалось подтвердить код. Попробуйте снова немного позже.',
        );
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
  Future<Result<MobileAuthSession?>> syncSession(
    MobileAuthSession session,
  ) async {
    try {
      final currentUserResponse = await _getCurrentUserResponse(
        session.accessToken,
      );

      if (currentUserResponse.isSuccess) {
        final currentUser = _parseCurrentUser(currentUserResponse.jsonBody);
        if (currentUser != null) {
          final updatedSession = session.copyWith(
            user: currentUser,
            phone: currentUser.phone,
            email: currentUser.email,
          );
          await _sessionStorage.saveSession(updatedSession);
          return Success<MobileAuthSession?>(updatedSession);
        }
      }

      if (currentUserResponse.statusCode == 401) {
        final refreshResponse = await _refreshSessionResponse(
          session.refreshToken,
        );

        if (refreshResponse.isSuccess) {
          final refreshedSession = await _storeTokenResponse(
            refreshResponse.jsonBody,
          );
          if (refreshedSession != null) {
            return Success<MobileAuthSession?>(refreshedSession);
          }
        }

        if (refreshResponse.statusCode == 401) {
          await _sessionStorage.clearSession();
          return const Success<MobileAuthSession?>(null);
        }

        return const Failure<MobileAuthSession?>(
          'Не удалось обновить профиль. Проверьте интернет и попробуйте снова.',
        );
      }

      return const Failure<MobileAuthSession?>(
        'Не удалось обновить профиль. Попробуйте снова немного позже.',
      );
    } catch (_) {
      return const Failure<MobileAuthSession?>(
        'Не удалось обновить профиль. Проверьте интернет и попробуйте снова.',
      );
    }
  }

  @override
  Future<Result<MobileAuthSession>> refreshSession(String refreshToken) async {
    try {
      final response = await _refreshSessionResponse(refreshToken);

      if (response.isSuccess) {
        final session = await _storeTokenResponse(response.jsonBody);
        if (session != null) {
          return Success<MobileAuthSession>(session);
        }
      }

      if (response.statusCode == 401) {
        await _sessionStorage.clearSession();
        return const Failure<MobileAuthSession>(
          'Сессия больше не действительна. Войдите снова.',
        );
      }

      return const Failure<MobileAuthSession>(
        'Не удалось восстановить сессию. Попробуйте снова немного позже.',
      );
    } catch (_) {
      return const Failure<MobileAuthSession>(
        'Не удалось восстановить сессию. Проверьте интернет и попробуйте снова.',
      );
    }
  }

  @override
  Future<Result<MobileAuthUser>> getCurrentUser(String accessToken) async {
    try {
      final response = await _getCurrentUserResponse(accessToken);

      if (response.isSuccess) {
        final currentUser = _parseCurrentUser(response.jsonBody);
        if (currentUser != null) {
          return Success<MobileAuthUser>(currentUser);
        }
      }

      if (response.statusCode == 401) {
        return const Failure<MobileAuthUser>(
          'Сессия больше не действительна. Войдите снова.',
        );
      }

      return const Failure<MobileAuthUser>(
        'Не удалось загрузить профиль. Попробуйте снова немного позже.',
      );
    } catch (_) {
      return const Failure<MobileAuthUser>(
        'Не удалось загрузить профиль. Проверьте интернет и попробуйте снова.',
      );
    }
  }

  @override
  Future<Result<void>> logout(MobileAuthSession session) async {
    try {
      final response = await _apiClient.postJson(
        '/auth/logout',
        body: const <String, dynamic>{},
        headers: buildMobileAuthAuthorizationHeader(session),
      );

      if (response.isSuccess || response.statusCode == 401) {
        await _sessionStorage.clearSession();
        return const Success<void>(null);
      }

      return const Failure<void>(
        'Не удалось завершить сеанс. Попробуйте снова немного позже.',
      );
    } catch (_) {
      return const Failure<void>(
        'Не удалось завершить сеанс. Проверьте интернет и попробуйте снова.',
      );
    }
  }

  @override
  Future<void> clearSession() {
    return _sessionStorage.clearSession();
  }

  Future<ApiClientResponse> _refreshSessionResponse(String refreshToken) {
    return _apiClient.postJson(
      '/auth/refresh',
      body: {'refresh_token': refreshToken},
    );
  }

  Future<ApiClientResponse> _getCurrentUserResponse(String accessToken) {
    return _apiClient.getJson(
      '/auth/current-user',
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
  }

  Future<MobileAuthSession?> _storeTokenResponse(Object? jsonBody) async {
    if (jsonBody is! Map<String, dynamic>) {
      return null;
    }

    final session = TokenResponseDto.fromJson(
      jsonBody,
    ).toDomain(verifiedAt: DateTime.now());
    await _sessionStorage.saveSession(session);
    return session;
  }

  Future<Result<MobileAuthSession>> _submitEmailAuth({
    required String path,
    required String email,
    required String password,
    String? duplicateEmailMessage,
    String? invalidCredentialsMessage,
    required String fallbackMessage,
  }) async {
    try {
      final response = await _apiClient.postJson(
        path,
        body: {
          'email': email.trim(),
          'password': password,
        },
      );

      if (response.isSuccess) {
        final session = await _storeTokenResponse(response.jsonBody);
        if (session != null) {
          return Success<MobileAuthSession>(session);
        }
      }

      if (response.statusCode == 409 && duplicateEmailMessage != null) {
        return Failure<MobileAuthSession>(duplicateEmailMessage);
      }

      if (response.statusCode == 401 && invalidCredentialsMessage != null) {
        return Failure<MobileAuthSession>(invalidCredentialsMessage);
      }

      if (response.statusCode == 422) {
        return const Failure<MobileAuthSession>(
          'Проверьте почту и пароль.',
        );
      }

      return Failure<MobileAuthSession>(fallbackMessage);
    } catch (_) {
      return Failure<MobileAuthSession>(fallbackMessage);
    }
  }

  MobileAuthUser? _parseCurrentUser(Object? jsonBody) {
    if (jsonBody is! Map<String, dynamic>) {
      return null;
    }

    return MobileAuthUserDto.fromJson(jsonBody).toDomain();
  }
}
