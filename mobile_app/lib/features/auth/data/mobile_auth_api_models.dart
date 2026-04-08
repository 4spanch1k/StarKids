import '../domain/mobile_auth_user.dart';
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
    required this.tokenType,
    required this.expiresInSeconds,
    required this.refreshExpiresInSeconds,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresInSeconds;
  final int refreshExpiresInSeconds;
  final MobileAuthUserDto user;

  factory TokenResponseDto.fromJson(Map<String, dynamic> json) {
    return TokenResponseDto(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      expiresInSeconds: (json['expires_in_seconds'] as int?) ?? 0,
      refreshExpiresInSeconds:
          (json['refresh_expires_in_seconds'] as int?) ?? 0,
      user: MobileAuthUserDto.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  MobileAuthSession toDomain({
    required DateTime verifiedAt,
  }) {
    final accessExpiresAt = expiresInSeconds > 0
        ? verifiedAt.add(Duration(seconds: expiresInSeconds))
        : null;
    final refreshExpiresAt = refreshExpiresInSeconds > 0
        ? verifiedAt.add(Duration(seconds: refreshExpiresInSeconds))
        : null;

    return MobileAuthSession(
      user: user.toDomain(),
      phone: user.phone,
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
      verifiedAt: verifiedAt,
    );
  }
}

class MobileAuthUserDto {
  const MobileAuthUserDto({
    required this.id,
    required this.phone,
  });

  final String id;
  final String phone;

  factory MobileAuthUserDto.fromJson(Map<String, dynamic> json) {
    return MobileAuthUserDto(
      id: json['id'] as String,
      phone: json['phone'] as String,
    );
  }

  MobileAuthUser toDomain() {
    return MobileAuthUser(
      id: id,
      phone: phone,
    );
  }
}
