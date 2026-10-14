class OtpChallenge {
  const OtpChallenge({
    required this.phone,
    required this.verificationId,
    required this.expiresIn,
    required this.requestedAt,
    this.resendAfter = Duration.zero,
  });

  final String phone;
  final String verificationId;
  final Duration expiresIn;
  final DateTime requestedAt;
  final Duration resendAfter;

  DateTime get expiresAt => requestedAt.add(expiresIn);
}
