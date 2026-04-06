class BirthdayRequestSubmission {
  const BirthdayRequestSubmission({
    required this.requestId,
    required this.submittedAt,
    required this.nextStep,
  });

  final String requestId;
  final DateTime submittedAt;
  final String nextStep;
}
