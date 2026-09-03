class MobileAuthUser {
  const MobileAuthUser({
    required this.id,
    this.phone,
    this.email,
  });

  final String id;
  final String? phone;
  final String? email;

  String get displayIdentity => email ?? phone ?? 'Аккаунт Boom Bala';
}
