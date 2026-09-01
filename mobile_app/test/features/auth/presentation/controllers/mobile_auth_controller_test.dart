import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_repository.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_session.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_user.dart';
import 'package:star_kids_mobile/features/auth/domain/otp_challenge.dart';
import 'package:star_kids_mobile/features/auth/presentation/controllers/mobile_auth_controller.dart';

void main() {
  group('MobileAuthController', () {
    test('bootstrap synchronizes restored session with backend user', () async {
      final restoredSession = MobileAuthSession(
        user: null,
        phone: '+77071234567',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        tokenType: 'bearer',
        verifiedAt: DateTime(2026, 4, 8),
      );
      final syncedSession = restoredSession.copyWith(
        user: const MobileAuthUser(
          id: 'user-1',
          phone: '+77071234567',
        ),
        tokenType: 'bearer',
      );
      final repository = _FakeMobileAuthRepository(
        restoredSession: restoredSession,
        syncSessionResult: Success<MobileAuthSession?>(syncedSession),
      );
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();

      expect(controller.status, MobileAuthStatus.authenticated);
      expect(controller.session?.user?.id, 'user-1');
      expect(repository.syncedAccessToken, 'access-token');
    });

    test('bootstrap clears stale session when backend rejects it', () async {
      final repository = _FakeMobileAuthRepository(
        restoredSession: MobileAuthSession(
          user: null,
          phone: '+77071234567',
          accessToken: 'expired-access',
          refreshToken: 'expired-refresh',
          tokenType: 'bearer',
          verifiedAt: DateTime(2026, 4, 8),
        ),
        syncSessionResult: const Success<MobileAuthSession?>(null),
      );
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();

      expect(controller.status, MobileAuthStatus.unauthenticated);
      expect(controller.session, isNull);
    });

    test('bootstrap clears restored session when sync fails', () async {
      final repository = _FakeMobileAuthRepository(
        restoredSession: MobileAuthSession(
          user: null,
          phone: '+77071234567',
          accessToken: 'stale-access',
          refreshToken: 'stale-refresh',
          tokenType: 'bearer',
          verifiedAt: DateTime(2026, 4, 8),
        ),
        syncSessionResult: const Failure<MobileAuthSession?>(
          'Не удалось обновить профиль.',
        ),
      );
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();

      expect(repository.wasCleared, isTrue);
      expect(controller.status, MobileAuthStatus.unauthenticated);
      expect(controller.session, isNull);
    });

    test('bootstrap without stored session resolves unauthenticated', () async {
      final repository = _FakeMobileAuthRepository();
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();

      expect(repository.wasCleared, isFalse);
      expect(controller.status, MobileAuthStatus.unauthenticated);
      expect(controller.session, isNull);
    });

    test('bootstrap clears session when sync throws', () async {
      final repository = _FakeMobileAuthRepository(
        restoredSession: MobileAuthSession(
          user: null,
          phone: '+77071234567',
          accessToken: 'stale-access',
          refreshToken: 'stale-refresh',
          tokenType: 'bearer',
          verifiedAt: DateTime(2026, 4, 8),
        ),
        syncSessionError: StateError('network failed'),
      );
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();

      expect(repository.wasCleared, isTrue);
      expect(controller.status, MobileAuthStatus.unauthenticated);
      expect(controller.session, isNull);
    });

    test('bootstrap clears session when storage restore throws', () async {
      final repository = _FakeMobileAuthRepository(
        restoreSessionError: StateError('storage failed'),
      );
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();

      expect(repository.wasCleared, isTrue);
      expect(controller.status, MobileAuthStatus.unauthenticated);
      expect(controller.session, isNull);
    });

    test('request otp normalizes phone and moves controller to otpRequested',
        () async {
      final repository = _FakeMobileAuthRepository();
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();
      await controller.requestOtp('8 707 123 45 67');

      expect(repository.requestedPhone, '+77071234567');
      expect(controller.status, MobileAuthStatus.otpRequested);
      expect(controller.pendingChallenge?.phone, '+77071234567');
    });

    test('verify otp authenticates session, refreshes profile and logs out',
        () async {
      final verifiedSession = MobileAuthSession(
        user: const MobileAuthUser(
          id: 'user-1',
          phone: '+77071234567',
        ),
        phone: '+77071234567',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        tokenType: 'bearer',
        verifiedAt: DateTime(2026, 4, 8, 12, 5),
      );
      final refreshedSession = verifiedSession.copyWith(
        user: const MobileAuthUser(
          id: 'user-1',
          phone: '+77071234567',
        ),
      );
      final repository = _FakeMobileAuthRepository(
        verifyResult: Success<MobileAuthSession>(verifiedSession),
        syncSessionResult: Success<MobileAuthSession?>(refreshedSession),
      );
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();
      await controller.requestOtp('+7 707 123 45 67');
      await controller.verifyOtp('1234');

      expect(repository.verifiedCode, '1234');
      expect(controller.status, MobileAuthStatus.authenticated);
      expect(controller.session?.user?.id, 'user-1');

      await controller.refreshProfile();

      expect(repository.syncedAccessToken, 'access-token');
      expect(controller.status, MobileAuthStatus.authenticated);

      await controller.logout();

      expect(repository.loggedOutAccessToken, 'access-token');
      expect(repository.wasCleared, isTrue);
      expect(controller.status, MobileAuthStatus.unauthenticated);
      expect(controller.session, isNull);
    });

    test('email login authenticates without otp challenge', () async {
      final emailSession = MobileAuthSession(
        user: const MobileAuthUser(
          id: 'user-email',
          email: 'parent@example.com',
        ),
        email: 'parent@example.com',
        accessToken: 'email-access-token',
        refreshToken: 'email-refresh-token',
        tokenType: 'bearer',
        verifiedAt: DateTime(2026, 4, 12, 10),
      );
      final repository = _FakeMobileAuthRepository(
        loginResult: Success<MobileAuthSession>(emailSession),
      );
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();
      await controller.loginWithEmail(
        email: ' PARENT@example.com ',
        password: 'strong-pass-123',
      );

      expect(repository.loginEmail, 'parent@example.com');
      expect(controller.status, MobileAuthStatus.authenticated);
      expect(controller.pendingChallenge, isNull);
      expect(controller.session?.user?.email, 'parent@example.com');
    });

    test('google clerk login exchanges token and authenticates', () async {
      final googleSession = MobileAuthSession(
        user: const MobileAuthUser(
          id: 'user-google',
          email: 'parent@example.com',
        ),
        email: 'parent@example.com',
        accessToken: 'star-kids-access-token',
        refreshToken: 'star-kids-refresh-token',
        tokenType: 'bearer',
        verifiedAt: DateTime(2026, 5, 24, 10),
      );
      final repository = _FakeMobileAuthRepository(
        exchangeResult: Success<MobileAuthSession>(googleSession),
      );
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();
      await controller.loginWithGoogleClerk(
        requestSessionToken: () async => ' clerk-session-token ',
      );

      expect(repository.exchangeSessionToken, 'clerk-session-token');
      expect(controller.status, MobileAuthStatus.authenticated);
      expect(controller.session?.accessToken, 'star-kids-access-token');
      expect(controller.session?.refreshToken, 'star-kids-refresh-token');
    });

    test('google clerk login sets error after exchange failure', () async {
      final repository = _FakeMobileAuthRepository(
        exchangeResult: const Failure<MobileAuthSession>(
          'Не удалось войти через Google.',
        ),
      );
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();
      await controller.loginWithGoogleClerk(
        requestSessionToken: () async => 'clerk-session-token',
      );

      expect(controller.status, MobileAuthStatus.error);
      expect(controller.session, isNull);
      expect(controller.errorMessage, 'Не удалось войти через Google.');
    });

    test('google cancellation returns controller to idle without an error',
        () async {
      final controller = MobileAuthController(
        repository: _FakeMobileAuthRepository(),
      );

      await controller.bootstrap();
      await controller.loginWithGoogleClerk(
        requestSessionToken: () async {
          throw const MobileAuthCancelledException();
        },
      );

      expect(controller.status, MobileAuthStatus.idle);
      expect(controller.errorMessage, isNull);
    });

    test('repeated Google taps do not start concurrent requests', () async {
      final controller = MobileAuthController(
        repository: _FakeMobileAuthRepository(),
      );
      final release = Completer<String>();
      var calls = 0;

      await controller.bootstrap();
      final first = controller.loginWithGoogleClerk(
        requestSessionToken: () {
          calls++;
          return release.future;
        },
      );
      final second = controller.loginWithGoogleClerk(
        requestSessionToken: () async {
          calls++;
          return 'unexpected';
        },
      );

      expect(calls, 1);
      release.complete('');
      await Future.wait([first, second]);
      expect(controller.status, MobileAuthStatus.error);
    });

    test('validates email password and confirmation inputs', () {
      final controller = MobileAuthController(
        repository: _FakeMobileAuthRepository(),
      );

      expect(
        controller.validateEmailInput(''),
        'Введите электронную почту.',
      );
      expect(
        controller.validateEmailInput('wrong-email'),
        'Введите корректную электронную почту.',
      );
      expect(controller.validateEmailInput('parent@example.com'), isNull);
      expect(controller.validatePasswordInput(''), 'Введите пароль.');
      expect(
        controller.validatePasswordInput('short'),
        'Пароль должен быть не короче 8 символов.',
      );
      expect(controller.validatePasswordInput('strong-pass-123'), isNull);
      expect(
        controller.validatePasswordConfirmation(
          password: 'strong-pass-123',
          confirmation: 'different-pass',
        ),
        'Пароли не совпадают.',
      );
    });
  });
}

class _FakeMobileAuthRepository implements MobileAuthRepository {
  _FakeMobileAuthRepository({
    this.restoredSession,
    Result<MobileAuthSession?>? syncSessionResult,
    Result<MobileAuthSession>? verifyResult,
    Result<MobileAuthSession>? registerResult,
    Result<MobileAuthSession>? loginResult,
    Result<MobileAuthSession>? exchangeResult,
    Result<void>? logoutResult,
    Object? restoreSessionError,
    Object? syncSessionError,
  })  : _syncSessionResult = syncSessionResult ??
            (restoredSession == null
                ? const Success<MobileAuthSession?>(null)
                : Success<MobileAuthSession?>(restoredSession)),
        _verifyResult = verifyResult,
        _registerResult = registerResult,
        _loginResult = loginResult,
        _exchangeResult = exchangeResult,
        _logoutResult = logoutResult ?? const Success<void>(null),
        _restoreSessionError = restoreSessionError,
        _syncSessionError = syncSessionError;

  final MobileAuthSession? restoredSession;
  final Result<MobileAuthSession?> _syncSessionResult;
  final Result<MobileAuthSession>? _verifyResult;
  final Result<MobileAuthSession>? _registerResult;
  final Result<MobileAuthSession>? _loginResult;
  final Result<MobileAuthSession>? _exchangeResult;
  final Result<void> _logoutResult;
  final Object? _restoreSessionError;
  final Object? _syncSessionError;

  String? requestedPhone;
  String? verifiedCode;
  String? registerEmail;
  String? loginEmail;
  String? exchangeSessionToken;
  String? syncedAccessToken;
  String? loggedOutAccessToken;
  bool wasCleared = false;

  @override
  Future<void> clearSession() async {
    wasCleared = true;
  }

  @override
  Future<Result<MobileAuthUser>> getCurrentUser(String accessToken) async {
    return const Failure<MobileAuthUser>('not used in controller test');
  }

  @override
  Future<Result<MobileAuthSession>> exchangeClerkSession({
    required String sessionToken,
  }) async {
    exchangeSessionToken = sessionToken;
    return _exchangeResult ??
        Success<MobileAuthSession>(
          MobileAuthSession(
            user: const MobileAuthUser(
              id: 'user-google',
              email: 'parent@example.com',
            ),
            email: 'parent@example.com',
            accessToken: 'google-access-token',
            refreshToken: 'google-refresh-token',
            tokenType: 'bearer',
            verifiedAt: DateTime(2026, 5, 24, 10),
          ),
        );
  }

  @override
  Future<Result<void>> logout(MobileAuthSession session) async {
    loggedOutAccessToken = session.accessToken;
    return _logoutResult;
  }

  @override
  Future<Result<MobileAuthSession>> refreshSession(String refreshToken) async {
    return const Failure<MobileAuthSession>('not used in controller test');
  }

  @override
  Future<Result<MobileAuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) async {
    registerEmail = email;
    return _registerResult ??
        Success<MobileAuthSession>(
          MobileAuthSession(
            user: MobileAuthUser(id: 'user-register', email: email),
            email: email,
            accessToken: 'register-access-token',
            refreshToken: 'register-refresh-token',
            tokenType: 'bearer',
            verifiedAt: DateTime(2026, 4, 12, 10),
          ),
        );
  }

  @override
  Future<Result<MobileAuthSession>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    loginEmail = email;
    return _loginResult ??
        Success<MobileAuthSession>(
          MobileAuthSession(
            user: MobileAuthUser(id: 'user-login', email: email),
            email: email,
            accessToken: 'login-access-token',
            refreshToken: 'login-refresh-token',
            tokenType: 'bearer',
            verifiedAt: DateTime(2026, 4, 12, 10),
          ),
        );
  }

  @override
  Future<Result<OtpChallenge>> requestOtp(String phone) async {
    requestedPhone = phone;
    return Success<OtpChallenge>(
      OtpChallenge(
        phone: phone,
        verificationId: 'otp_123',
        expiresIn: const Duration(minutes: 5),
        requestedAt: DateTime(2026, 4, 8, 12),
      ),
    );
  }

  @override
  Future<MobileAuthSession?> restoreSession() async {
    final error = _restoreSessionError;
    if (error != null) {
      throw error;
    }
    return restoredSession;
  }

  @override
  Future<Result<MobileAuthSession?>> syncSession(
      MobileAuthSession session) async {
    final error = _syncSessionError;
    if (error != null) {
      throw error;
    }
    syncedAccessToken = session.accessToken;
    return _syncSessionResult;
  }

  @override
  Future<Result<MobileAuthSession>> verifyOtp({
    required String phone,
    required String code,
    required String verificationId,
  }) async {
    verifiedCode = code;
    return _verifyResult ??
        Success<MobileAuthSession>(
          MobileAuthSession(
            user: const MobileAuthUser(
              id: 'user-1',
              phone: '+77071234567',
            ),
            phone: phone,
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            tokenType: 'bearer',
            verifiedAt: DateTime(2026, 4, 8, 12, 5),
          ),
        );
  }
}
