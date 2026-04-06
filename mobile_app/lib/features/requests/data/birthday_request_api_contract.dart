/// Frontend expectation for `POST /leads/birthday`.
///
/// Request body:
/// {
///   "branchId": "shymkent-mega",
///   "packageId": "star-show",
///   "name": "Айдана",
///   "phone": "+77070000000",
///   "preferredDate": "2026-04-10",
///   "guestCount": 12,
///   "comment": "Нужен аниматор и торт"
/// }
///
/// Success response:
/// {
///   "requestId": "lead_123",
///   "submittedAt": "2026-04-06T12:00:00Z",
///   "nextStep": "Менеджер свяжется с вами для подтверждения деталей"
/// }
///
/// Error response:
/// {
///   "message": "Не удалось отправить заявку"
/// }
///
/// Validation error response:
/// {
///   "message": "Validation error",
///   "errors": {
///     "phone": ["Введите корректный номер"],
///     "preferredDate": ["Дата недоступна"]
///   }
/// }
abstract final class BirthdayRequestApiContract {
  static const endpoint = '/leads/birthday';

  static const branchId = 'branchId';
  static const packageId = 'packageId';
  static const name = 'name';
  static const phone = 'phone';
  static const preferredDate = 'preferredDate';
  static const guestCount = 'guestCount';
  static const comment = 'comment';

  static const requestId = 'requestId';
  static const submittedAt = 'submittedAt';
  static const nextStep = 'nextStep';

  static const message = 'message';
  static const errors = 'errors';
}
