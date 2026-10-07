class CustomerQr {
  const CustomerQr({required this.qrPayload, required this.expiresAt});

  final String qrPayload;
  final DateTime expiresAt;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  Duration get remaining => expiresAt.difference(DateTime.now().toUtc());
}
