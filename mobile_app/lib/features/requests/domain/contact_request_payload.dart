class ContactRequestPayload {
  const ContactRequestPayload({
    required this.name,
    required this.phone,
    this.email,
    this.message,
  });

  final String name;
  final String phone;
  final String? email;
  final String? message;
}
