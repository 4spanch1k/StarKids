class MobileAuthSession {
  const MobileAuthSession({
    required this.phone,
    required this.accessToken,
    required this.refreshToken,
    required this.verifiedAt,
  });

  final String phone;
  final String accessToken;
  final String refreshToken;
  final DateTime verifiedAt;
}
