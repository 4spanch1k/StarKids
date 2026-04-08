import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_repository.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_session.dart';
import 'package:star_kids_mobile/features/auth/domain/otp_challenge.dart';
import 'package:star_kids_mobile/features/auth/presentation/controllers/mobile_auth_controller.dart';

void main() {
  group('MobileAuthController', () {
    test('bootstrap restores authenticated session when one exists', () async {
      final repository = _FakeMobileAuthRepository(
        restoredSession: MobileAuthSession(
          phone: '+77071234567',
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          verifiedAt: DateTime(2026, 4, 8),
        ),
      );
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();

      expect(controller.status, MobileAuthStatus.authenticated);
      expect(controller.session?.phone, '+77071234567');
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

    test('verify otp authenticates session and logout clears it', () async {
      final repository = _FakeMobileAuthRepository();
      final controller = MobileAuthController(repository: repository);

      await controller.bootstrap();
      await controller.requestOtp('+7 707 123 45 67');
      await controller.verifyOtp('1234');

      expect(repository.verifiedCode, '1234');
      expect(controller.status, MobileAuthStatus.authenticated);
      expect(controller.session?.phone, '+77071234567');

      await controller.logout();

      expect(repository.wasCleared, isTrue);
      expect(controller.status, MobileAuthStatus.unauthenticated);
      expect(controller.session, isNull);
    });
  });
}

class _FakeMobileAuthRepository implements MobileAuthRepository {
  _FakeMobileAuthRepository({
    this.restoredSession,
  });

  final MobileAuthSession? restoredSession;
  String? requestedPhone;
  String? verifiedCode;
  bool wasCleared = false;

  @override
  Future<void> clearSession() async {
    wasCleared = true;
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
  Future<Result<MobileAuthSession>> verifyOtp({
    required String phone,
    required String code,
    required String verificationId,
  }) async {
    verifiedCode = code;
    return Success<MobileAuthSession>(
      MobileAuthSession(
        phone: phone,
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        verifiedAt: DateTime(2026, 4, 8, 12, 5),
      ),
    );
  }
}
