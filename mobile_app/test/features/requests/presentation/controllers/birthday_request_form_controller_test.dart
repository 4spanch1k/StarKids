import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/birthdays/domain/birthday_package.dart';
import 'package:star_kids_mobile/features/birthdays/domain/birthday_package_repository.dart';
import 'package:star_kids_mobile/features/requests/domain/birthday_request_payload.dart';
import 'package:star_kids_mobile/features/requests/domain/birthday_request_repository.dart';
import 'package:star_kids_mobile/features/requests/domain/birthday_request_submission.dart';
import 'package:star_kids_mobile/features/children/domain/child.dart';
import 'package:star_kids_mobile/features/requests/presentation/controllers/birthday_request_form_controller.dart';

void main() {
  test('optional package, child and date do not block a lead', () async {
    final repository = _SuccessBirthdayRequestRepository();
    final controller = BirthdayRequestFormController(
      repository: repository,
      packageRepository: _FakeBirthdayPackageRepository(),
    );
    addTearDown(controller.dispose);

    controller.nameController.text = 'Амина';
    controller.phoneController.text = '+7 707 000 00 00';

    expect(controller.validateSelections(), isTrue);
    await controller.submit(branchId: 'branch-main');

    expect(controller.status, BirthdayRequestSubmissionStatus.success);
    expect(repository.payloads.single.packageId, isNull);
    expect(repository.payloads.single.childId, isNull);
    expect(repository.payloads.single.preferredDate, isNull);
    expect(repository.payloads.single.guestCount, 10);
  });

  test('resetForm creates a new idempotency key for a new submission', () {
    final controller = BirthdayRequestFormController(
      repository: _FailureBirthdayRequestRepository(),
      packageRepository: _FakeBirthdayPackageRepository(),
    );
    addTearDown(controller.dispose);

    final firstKey = controller.idempotencyKey;
    controller.resetForm();

    expect(controller.idempotencyKey, isNot(firstKey));
  });

  test('birthday context preselects child/date and reaches the lead payload',
      () async {
    final repository = _SuccessBirthdayRequestRepository();
    final controller = BirthdayRequestFormController(
      repository: repository,
      packageRepository: _FakeBirthdayPackageRepository(),
      initialChildId: 'child-1',
      initialPreferredDate: DateTime(2026, 10, 6),
      sourceCampaignId: 'campaign-1',
      birthdayCycleId: 'cycle-1',
    );
    addTearDown(controller.dispose);
    controller.selectInitialChild([
      Child(
          id: 'child-1',
          name: 'Аяна',
          birthDate: DateTime(2020, 10, 6),
          gender: ChildGender.female),
    ]);
    controller.nameController.text = 'Амина';
    controller.phoneController.text = '+7 707 000 00 00';
    await controller.submit(branchId: 'branch-main');

    expect(controller.selectedChild?.id, 'child-1');
    expect(controller.desiredDate, DateTime(2026, 10, 6));
    expect(repository.payloads.single.sourceCampaignId, 'campaign-1');
    expect(repository.payloads.single.birthdayCycleId, 'cycle-1');
  });

  test('submit stays in error state when backend submission fails', () async {
    final controller = BirthdayRequestFormController(
      repository: _FailureBirthdayRequestRepository(),
      packageRepository: _FakeBirthdayPackageRepository(),
    );
    addTearDown(controller.dispose);

    controller.nameController.text = 'Амина';
    controller.phoneController.text = '+7 707 000 00 00';
    controller.guestCountController.text = '10';
    controller.updateSelectedPackage('package-main');
    controller.updateDesiredDate(DateTime(2026, 4, 20));

    await controller.submit(branchId: 'branch-main');

    expect(controller.status, BirthdayRequestSubmissionStatus.error);
    expect(controller.submission, isNull);
    expect(controller.submissionErrorText, isNotEmpty);
  });
}

class _SuccessBirthdayRequestRepository implements BirthdayRequestRepository {
  final payloads = <BirthdayRequestPayload>[];

  @override
  Future<Result<BirthdayRequestSubmission>> submitBirthdayRequest(
    BirthdayRequestPayload payload,
  ) async {
    payloads.add(payload);
    return Success(
      BirthdayRequestSubmission(
        requestId: 'request-1',
        submittedAt: DateTime(2026, 4, 20),
        nextStep: 'Менеджер свяжется с вами',
      ),
    );
  }
}

class _FailureBirthdayRequestRepository implements BirthdayRequestRepository {
  @override
  Future<Result<BirthdayRequestSubmission>> submitBirthdayRequest(
    BirthdayRequestPayload payload,
  ) async {
    return const Failure<BirthdayRequestSubmission>(
      'Не удалось отправить заявку. Проверьте интернет и попробуйте снова.',
    );
  }
}

class _FakeBirthdayPackageRepository implements BirthdayPackageRepository {
  @override
  Future<BirthdayPackage?> getPackageById(String packageId) async {
    return null;
  }

  @override
  Future<List<BirthdayPackage>> listPackages({String? branchId}) async {
    return const [];
  }
}
