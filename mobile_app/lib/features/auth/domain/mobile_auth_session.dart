import 'mobile_auth_user.dart';

class MobileAuthSession {
  const MobileAuthSession({
    required this.user,
    required this.phone,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    this.accessExpiresAt,
    this.refreshExpiresAt,
    required this.verifiedAt,
  });

  final MobileAuthUser? user;
  final String phone;
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime? accessExpiresAt;
  final DateTime? refreshExpiresAt;
  final DateTime verifiedAt;

  MobileAuthSession copyWith({
    MobileAuthUser? user,
    String? phone,
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    DateTime? accessExpiresAt,
    DateTime? refreshExpiresAt,
    DateTime? verifiedAt,
    bool clearAccessExpiresAt = false,
    bool clearRefreshExpiresAt = false,
  }) {
    return MobileAuthSession(
      user: user ?? this.user,
      phone: phone ?? this.phone,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      accessExpiresAt:
          clearAccessExpiresAt ? null : accessExpiresAt ?? this.accessExpiresAt,
      refreshExpiresAt: clearRefreshExpiresAt
          ? null
          : refreshExpiresAt ?? this.refreshExpiresAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}
