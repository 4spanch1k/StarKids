import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/requests/domain/contact_request_payload.dart';
import 'package:star_kids_mobile/features/requests/domain/contact_request_repository.dart';
import 'package:star_kids_mobile/features/requests/domain/contact_request_submission.dart';
import 'package:star_kids_mobile/features/requests/presentation/controllers/contact_request_form_controller.dart';

void main() {
  test('submit stays in error state when contact submission fails', () async {
    final controller = ContactRequestFormController(
      repository: _FailureContactRequestRepository(),
    );
    addTearDown(controller.dispose);

    controller.nameController.text = 'Амина';
    controller.phoneController.text = '+7 707 000 00 00';
    controller.messageController.text = 'Подскажите свободные даты.';

    await controller.submit();

    expect(controller.status, ContactRequestSubmissionStatus.error);
    expect(controller.submission, isNull);
    expect(controller.submissionErrorText, isNotEmpty);
  });

  test('resetForm restores initial contact context message', () async {
    final controller = ContactRequestFormController(
      repository: _FailureContactRequestRepository(),
      initialMessage: 'Интересует филиал Star Kids Main.',
    );
    addTearDown(controller.dispose);

    controller.messageController.text = 'Измененный текст';
    controller.resetForm();

    expect(
      controller.messageController.text,
      'Интересует филиал Star Kids Main.',
    );
    expect(controller.hasInitialMessage, isTrue);
  });
}

class _FailureContactRequestRepository implements ContactRequestRepository {
  @override
  Future<Result<ContactRequestSubmission>> submitContactRequest(
    ContactRequestPayload payload,
  ) async {
    return const Failure<ContactRequestSubmission>(
      'Не удалось отправить запрос. Проверьте интернет и попробуйте снова.',
    );
  }
}
