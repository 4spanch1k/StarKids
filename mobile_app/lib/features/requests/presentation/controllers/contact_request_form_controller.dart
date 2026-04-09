import 'package:flutter/material.dart';

import '../../../../core/utils/result.dart';
import '../../domain/contact_request_payload.dart';
import '../../domain/contact_request_repository.dart';
import '../../domain/contact_request_submission.dart';
import '../formatters/kz_phone_input_formatter.dart';

enum ContactRequestSubmissionStatus {
  idle,
  submitting,
  success,
  error,
}

class ContactRequestFormController extends ChangeNotifier {
  ContactRequestFormController({
    required ContactRequestRepository repository,
  }) : _repository = repository;

  static final RegExp _emailPattern = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  final ContactRequestRepository _repository;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final messageController = TextEditingController();

  ContactRequestSubmission? _submission;
  String? _submissionErrorText;
  ContactRequestSubmissionStatus _status = ContactRequestSubmissionStatus.idle;

  ContactRequestSubmission? get submission => _submission;
  String? get submissionErrorText => _submissionErrorText;
  ContactRequestSubmissionStatus get status => _status;
  bool get isSubmitting => _status == ContactRequestSubmissionStatus.submitting;

  Future<void> submit() async {
    _submissionErrorText = null;
    _status = ContactRequestSubmissionStatus.submitting;
    notifyListeners();

    final result = await _repository.submitContactRequest(
      ContactRequestPayload(
        name: nameController.text.trim(),
        phone: KzPhoneInputFormatter.normalizeForSubmit(phoneController.text),
        email: _normalizeOptional(emailController.text),
        message: _normalizeOptional(messageController.text),
      ),
    );

    if (result is Success<ContactRequestSubmission>) {
      _submission = result.data;
      _status = ContactRequestSubmissionStatus.success;
      notifyListeners();
      return;
    }

    _submissionErrorText =
        (result as Failure<ContactRequestSubmission>).message;
    _status = ContactRequestSubmissionStatus.error;
    notifyListeners();
  }

  void resetForm() {
    nameController.clear();
    phoneController.clear();
    emailController.clear();
    messageController.clear();
    _submission = null;
    _submissionErrorText = null;
    _status = ContactRequestSubmissionStatus.idle;
    notifyListeners();
  }

  void clearTransientFeedback() {
    if (_status == ContactRequestSubmissionStatus.error) {
      _submissionErrorText = null;
      _status = ContactRequestSubmissionStatus.idle;
      notifyListeners();
    }
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

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return null;
    }

    if (!_emailPattern.hasMatch(email)) {
      return 'Введите корректный email или оставьте поле пустым.';
    }

    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    messageController.dispose();
    super.dispose();
  }

  String? _normalizeOptional(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
