import 'package:flutter/material.dart';

import '../../../../core/utils/result.dart';
import '../../../birthdays/data/birthday_package_seed_data.dart';
import '../../../birthdays/domain/birthday_package.dart';
import '../../domain/birthday_request_payload.dart';
import '../../domain/birthday_request_repository.dart';
import '../../domain/birthday_request_submission.dart';
import '../formatters/kz_phone_input_formatter.dart';

enum BirthdayRequestSubmissionStatus {
  idle,
  submitting,
  success,
  error,
}

class BirthdayRequestFormController extends ChangeNotifier {
  BirthdayRequestFormController({
    required BirthdayRequestRepository repository,
    String? initialPackageId,
  })  : _repository = repository,
        _selectedPackageId = initialPackageId {
    final suggestedGuests = _extractGuestCount(
      getBirthdayPackageById(initialPackageId),
    );

    if (suggestedGuests != null) {
      guestCountController.text = suggestedGuests.toString();
    }
  }

  final BirthdayRequestRepository _repository;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final guestCountController = TextEditingController();
  final commentController = TextEditingController();

  String? _selectedPackageId;
  DateTime? _desiredDate;
  String? _packageErrorText;
  String? _dateErrorText;
  String? _submissionErrorText;
  BirthdayRequestSubmission? _submission;
  BirthdayRequestSubmissionStatus _status =
      BirthdayRequestSubmissionStatus.idle;

  BirthdayPackage? get selectedPackage =>
      getBirthdayPackageById(_selectedPackageId);

  String? get selectedPackageId => _selectedPackageId;

  DateTime? get desiredDate => _desiredDate;

  String? get packageErrorText => _packageErrorText;

  String? get dateErrorText => _dateErrorText;

  String? get submissionErrorText => _submissionErrorText;

  BirthdayRequestSubmission? get submission => _submission;

  BirthdayRequestSubmissionStatus get status => _status;

  bool get isSubmitting =>
      _status == BirthdayRequestSubmissionStatus.submitting;

  void updateSelectedPackage(String? packageId) {
    _selectedPackageId = packageId;
    _packageErrorText = null;
    clearTransientFeedback();

    final suggestedGuests =
        _extractGuestCount(getBirthdayPackageById(packageId));
    if (suggestedGuests != null && guestCountController.text.trim().isEmpty) {
      guestCountController.text = suggestedGuests.toString();
    }

    notifyListeners();
  }

  void updateDesiredDate(DateTime? value) {
    _desiredDate = value;
    _dateErrorText = null;
    clearTransientFeedback();
    notifyListeners();
  }

  Future<void> pickDesiredDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _desiredDate ?? now.add(const Duration(days: 7));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      updateDesiredDate(selectedDate);
    }
  }

  bool validateSelections() {
    _packageErrorText =
        _selectedPackageId == null ? 'Выберите пакет для праздника.' : null;
    _dateErrorText = _desiredDate == null ? 'Укажите желаемую дату.' : null;
    notifyListeners();

    return _packageErrorText == null && _dateErrorText == null;
  }

  Future<void> submit({
    required String branchId,
  }) async {
    _submissionErrorText = null;
    _status = BirthdayRequestSubmissionStatus.submitting;
    notifyListeners();

    final result = await _repository.submitBirthdayRequest(
      BirthdayRequestPayload(
        branchId: branchId,
        packageId: _selectedPackageId,
        name: nameController.text.trim(),
        phone: KzPhoneInputFormatter.normalizeForSubmit(phoneController.text),
        preferredDate: _desiredDate!,
        guestCount: int.parse(guestCountController.text.trim()),
        comment: _normalizeComment(commentController.text),
      ),
    );

    if (result is Success<BirthdayRequestSubmission>) {
      _submission = result.data;
      _status = BirthdayRequestSubmissionStatus.success;
      notifyListeners();
      return;
    }

    _submissionErrorText =
        (result as Failure<BirthdayRequestSubmission>).message;
    _status = BirthdayRequestSubmissionStatus.error;
    notifyListeners();
  }

  void resetSubmissionState() {
    _submission = null;
    _submissionErrorText = null;
    _status = BirthdayRequestSubmissionStatus.idle;
    notifyListeners();
  }

  void clearTransientFeedback() {
    if (_status == BirthdayRequestSubmissionStatus.error) {
      _submissionErrorText = null;
      _status = BirthdayRequestSubmissionStatus.idle;
      notifyListeners();
    }
  }

  void resetForm({
    bool preserveSelectedPackage = false,
  }) {
    final preservedPackageId =
        preserveSelectedPackage ? _selectedPackageId : null;

    nameController.clear();
    phoneController.clear();
    guestCountController.clear();
    commentController.clear();
    _selectedPackageId = preservedPackageId;
    _desiredDate = null;
    _packageErrorText = null;
    _dateErrorText = null;
    _submission = null;
    _submissionErrorText = null;
    _status = BirthdayRequestSubmissionStatus.idle;

    final suggestedGuests =
        _extractGuestCount(getBirthdayPackageById(_selectedPackageId));
    if (suggestedGuests != null) {
      guestCountController.text = suggestedGuests.toString();
    }

    notifyListeners();
  }

  String? validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Укажите имя родителя.';
    }

    if (name.length < 2) {
      return 'Имя должно быть не короче 2 символов.';
    }

    return null;
  }

  String? validatePhone(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Введите телефон для связи.';
    }

    if (!KzPhoneInputFormatter.isValid(value)) {
      return 'Введите номер в формате +7 777 123 45 67.';
    }

    return null;
  }

  String? validateGuestCount(String? value) {
    final parsedValue = int.tryParse(value?.trim() ?? '');

    if (parsedValue == null) {
      return 'Укажите количество гостей.';
    }

    if (parsedValue < 1) {
      return 'Количество гостей должно быть больше нуля.';
    }

    if (parsedValue > 50) {
      return 'Для групп больше 50 гостей нужен отдельный сценарий.';
    }

    return null;
  }

  String formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }

    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$day.$month.${value.year}';
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    guestCountController.dispose();
    commentController.dispose();
    super.dispose();
  }

  static String? _normalizeComment(String value) {
    final comment = value.trim();
    return comment.isEmpty ? null : comment;
  }

  static int? _extractGuestCount(BirthdayPackage? package) {
    if (package == null) {
      return null;
    }

    final match = RegExp(r'\d+').firstMatch(package.guestLabel);
    return match == null ? null : int.tryParse(match.group(0)!);
  }
}
