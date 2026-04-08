import '../domain/mobile_auth_session.dart';
import '../domain/otp_challenge.dart';

class OtpRequestResponseDto {
  const OtpRequestResponseDto({
    required this.verificationId,
    required this.expiresInSeconds,
  });

  final String verificationId;
  final int expiresInSeconds;

  factory OtpRequestResponseDto.fromJson(Map<String, dynamic> json) {
    return OtpRequestResponseDto(
      verificationId: json['verification_id'] as String,
      expiresInSeconds: json['expires_in_seconds'] as int,
    );
  }

  OtpChallenge toDomain({
    required String phone,
    required DateTime requestedAt,
  }) {
    return OtpChallenge(
      phone: phone,
      verificationId: verificationId,
      expiresIn: Duration(seconds: expiresInSeconds),
      requestedAt: requestedAt,
    );
  }
}

class TokenResponseDto {
  const TokenResponseDto({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  factory TokenResponseDto.fromJson(Map<String, dynamic> json) {
    return TokenResponseDto(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }

  MobileAuthSession toDomain({
    required String phone,
    required DateTime verifiedAt,
  }) {
    return MobileAuthSession(
      phone: phone,
      accessToken: accessToken,
      refreshToken: refreshToken,
      verifiedAt: verifiedAt,
    );
  }
}
