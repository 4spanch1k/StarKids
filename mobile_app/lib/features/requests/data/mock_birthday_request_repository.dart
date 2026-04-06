import '../../../core/utils/result.dart';
import '../domain/birthday_request_payload.dart';
import '../domain/birthday_request_repository.dart';
import '../domain/birthday_request_submission.dart';

class MockBirthdayRequestRepository implements BirthdayRequestRepository {
  @override
  Future<Result<BirthdayRequestSubmission>> submitBirthdayRequest(
    BirthdayRequestPayload payload,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (payload.guestCount > 30) {
      return const Failure<BirthdayRequestSubmission>(
        'Для мероприятий больше 30 гостей менеджер оформляет запрос вручную. Уточните детали по телефону или уменьшите количество гостей.',
      );
    }

    return Success<BirthdayRequestSubmission>(
      BirthdayRequestSubmission(
        requestId: 'bday-${DateTime.now().millisecondsSinceEpoch}',
        submittedAt: DateTime.now(),
        nextStep:
            'Менеджер Star Kids свяжется с вами для подтверждения даты и деталей праздника.',
      ),
    );
  }
}
