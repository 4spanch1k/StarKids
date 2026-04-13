import 'mobile_auth_user.dart';
import '../../../core/utils/result.dart';
import 'mobile_auth_session.dart';
import 'otp_challenge.dart';

abstract interface class MobileAuthRepository {
  Future<Result<MobileAuthSession>> registerWithEmail({
    required String email,
    required String password,
  });

  Future<Result<MobileAuthSession>> loginWithEmail({
    required String email,
    required String password,
  });

  Future<Result<OtpChallenge>> requestOtp(String phone);

  Future<Result<MobileAuthSession>> verifyOtp({
    required String phone,
    required String code,
    required String verificationId,
  });

  Future<MobileAuthSession?> restoreSession();

  Future<Result<MobileAuthSession?>> syncSession(MobileAuthSession session);

  Future<Result<MobileAuthSession>> refreshSession(String refreshToken);

  Future<Result<MobileAuthUser>> getCurrentUser(String accessToken);

  Future<Result<void>> logout(MobileAuthSession session);

  Future<void> clearSession();
}
