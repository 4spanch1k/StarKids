import 'mobile_auth_user.dart';

class MobileAuthSession {
  const MobileAuthSession({
    required this.user,
    this.phone,
    this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    this.accessExpiresAt,
    this.refreshExpiresAt,
    required this.verifiedAt,
  });

  final MobileAuthUser? user;
  final String? phone;
  final String? email;
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime? accessExpiresAt;
  final DateTime? refreshExpiresAt;
  final DateTime verifiedAt;

  MobileAuthSession copyWith({
    MobileAuthUser? user,
    String? phone,
    String? email,
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    DateTime? accessExpiresAt,
    DateTime? refreshExpiresAt,
    DateTime? verifiedAt,
    bool clearAccessExpiresAt = false,
    bool clearRefreshExpiresAt = false,
    bool clearPhone = false,
    bool clearEmail = false,
  }) {
    return MobileAuthSession(
      user: user ?? this.user,
      phone: clearPhone ? null : phone ?? this.phone,
      email: clearEmail ? null : email ?? this.email,
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
