import 'package:flutter/material.dart';

import '../../../../core/utils/result.dart';
import '../../../birthdays/domain/birthday_package.dart';
import '../../../birthdays/domain/birthday_package_repository.dart';
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
    required BirthdayPackageRepository packageRepository,
    String? initialPackageId,
    BirthdayPackage? initialPackage,
  })  : _repository = repository,
        _packageRepository = packageRepository,
        _selectedPackageId = initialPackage?.id ?? initialPackageId,
        _selectedPackage = initialPackage {
    if (initialPackage != null) {
      _applySuggestedGuests(initialPackage);
    } else if (initialPackageId != null) {
      _hydrateInitialPackage(initialPackageId);
    }
  }

  final BirthdayRequestRepository _repository;
  final BirthdayPackageRepository _packageRepository;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final guestCountController = TextEditingController();
  final commentController = TextEditingController();

  String? _selectedPackageId;
  BirthdayPackage? _selectedPackage;
  DateTime? _desiredDate;
  String? _packageErrorText;
  String? _dateErrorText;
  String? _submissionErrorText;
  BirthdayRequestSubmission? _submission;
  BirthdayRequestSubmissionStatus _status =
      BirthdayRequestSubmissionStatus.idle;
  bool _isDisposed = false;

  BirthdayPackage? get selectedPackage => _selectedPackage;

  String? get selectedPackageId => _selectedPackageId;

  DateTime? get desiredDate => _desiredDate;

  String? get packageErrorText => _packageErrorText;

  String? get dateErrorText => _dateErrorText;

  String? get submissionErrorText => _submissionErrorText;

  BirthdayRequestSubmission? get submission => _submission;

  BirthdayRequestSubmissionStatus get status => _status;

  bool get isSubmitting =>
      _status == BirthdayRequestSubmissionStatus.submitting;

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  void updateSelectedPackage(
    String? packageId, {
    BirthdayPackage? selectedPackage,
  }) {
    _selectedPackageId = packageId;
    _selectedPackage = selectedPackage;
    _packageErrorText = null;
    clearTransientFeedback();

    if (selectedPackage != null && guestCountController.text.trim().isEmpty) {
      _applySuggestedGuests(selectedPackage);
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

    if (selectedDate != null && !_isDisposed) {
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
    final preservedPackage = preserveSelectedPackage ? _selectedPackage : null;

    nameController.clear();
    phoneController.clear();
    guestCountController.clear();
    commentController.clear();
    _selectedPackageId = preservedPackageId;
    _selectedPackage = preservedPackage;
    _desiredDate = null;
    _packageErrorText = null;
    _dateErrorText = null;
    _submission = null;
    _submissionErrorText = null;
    _status = BirthdayRequestSubmissionStatus.idle;

    if (_selectedPackage != null) {
      _applySuggestedGuests(_selectedPackage!);
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
    _isDisposed = true;
    nameController.dispose();
    phoneController.dispose();
    guestCountController.dispose();
    commentController.dispose();
    super.dispose();
  }

  Future<void> _hydrateInitialPackage(String packageId) async {
    final package = await _packageRepository.getPackageById(packageId);
    if (package == null || _isDisposed) {
      return;
    }

    _selectedPackage = package;
    _applySuggestedGuests(package);
    notifyListeners();
  }

  void _applySuggestedGuests(BirthdayPackage package) {
    final suggestedGuests = _extractGuestCount(package);
    if (suggestedGuests != null) {
      guestCountController.text = suggestedGuests.toString();
    }
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
