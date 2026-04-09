/// Frontend expectation for `POST /leads/contact`.
///
/// Request body:
/// {
///   "name": "Айдана",
///   "phone": "+77070000000",
///   "email": "aidana@example.com",
///   "message": "Подскажите свободные даты"
/// }
///
/// Success response:
/// {
///   "id": "lead_123",
///   "type": "contact",
///   "status": "new"
/// }
abstract final class ContactRequestApiContract {
  static const endpoint = '/leads/contact';

  static const id = 'id';
  static const type = 'type';
  static const status = 'status';

  static const name = 'name';
  static const phone = 'phone';
  static const email = 'email';
  static const message = 'message';
}
