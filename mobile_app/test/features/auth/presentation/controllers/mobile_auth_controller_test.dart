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

    test('validates email password and confirmation inputs', () {
      final controller = MobileAuthController(
        repository: _FakeMobileAuthRepository(),
      );

      expect(controller.validateEmailInput(''), 'Введите email.');
      expect(
        controller.validateEmailInput('wrong-email'),
        'Введите корректный email.',
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
    Result<void>? logoutResult,
  })  : _syncSessionResult = syncSessionResult ??
            (restoredSession == null
                ? const Success<MobileAuthSession?>(null)
                : Success<MobileAuthSession?>(restoredSession)),
        _verifyResult = verifyResult,
        _registerResult = registerResult,
        _loginResult = loginResult,
        _logoutResult = logoutResult ?? const Success<void>(null);

  final MobileAuthSession? restoredSession;
  final Result<MobileAuthSession?> _syncSessionResult;
  final Result<MobileAuthSession>? _verifyResult;
  final Result<MobileAuthSession>? _registerResult;
  final Result<MobileAuthSession>? _loginResult;
  final Result<void> _logoutResult;

  String? requestedPhone;
  String? verifiedCode;
  String? registerEmail;
  String? loginEmail;
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
    return restoredSession;
  }

  @override
  Future<Result<MobileAuthSession?>> syncSession(
      MobileAuthSession session) async {
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
