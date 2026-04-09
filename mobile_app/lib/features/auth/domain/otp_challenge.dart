class OtpChallenge {
  const OtpChallenge({
    required this.phone,
    required this.verificationId,
    required this.expiresIn,
    required this.requestedAt,
  });

  final String phone;
  final String verificationId;
  final Duration expiresIn;
  final DateTime requestedAt;

  DateTime get expiresAt => requestedAt.add(expiresIn);
}
