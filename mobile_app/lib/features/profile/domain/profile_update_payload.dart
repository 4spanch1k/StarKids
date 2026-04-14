class ProfileUpdatePayload {
  const ProfileUpdatePayload({
    this.firstName,
    this.lastName,
    this.email,
    this.childBirthDate,
  });

  final String? firstName;
  final String? lastName;
  final String? email;
  final DateTime? childBirthDate;
}
