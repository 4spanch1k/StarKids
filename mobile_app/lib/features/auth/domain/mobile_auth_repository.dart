import '../../../core/utils/result.dart';
import 'mobile_auth_session.dart';
import 'otp_challenge.dart';

abstract interface class MobileAuthRepository {
  Future<Result<OtpChallenge>> requestOtp(String phone);

  Future<Result<MobileAuthSession>> verifyOtp({
    required String phone,
    required String code,
    required String verificationId,
  });

  Future<MobileAuthSession?> restoreSession();

  Future<void> clearSession();
}
