import 'package:flutter/material.dart';

import '../../../../core/utils/result.dart';
import '../../domain/mobile_auth_repository.dart';
import '../../domain/mobile_auth_session.dart';
import '../../domain/otp_challenge.dart';

enum MobileAuthStatus {
  idle,
  loading,
  otpRequested,
  verifying,
  authenticated,
  unauthenticated,
  error,
}

class MobileAuthController extends ChangeNotifier {
  MobileAuthController({
    required MobileAuthRepository repository,
  }) : _repository = repository;

  final MobileAuthRepository _repository;

  MobileAuthStatus _status = MobileAuthStatus.idle;
  MobileAuthSession? _session;
  OtpChallenge? _pendingChallenge;
  String? _errorMessage;
  bool _isRefreshingProfile = false;
  bool _isLoggingOut = false;

  MobileAuthStatus get status => _status;

  MobileAuthSession? get session => _session;

  OtpChallenge? get pendingChallenge => _pendingChallenge;

  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _session != null;

  bool get isRefreshingProfile => _isRefreshingProfile;

  bool get isLoggingOut => _isLoggingOut;

  bool get isBusy =>
      _status == MobileAuthStatus.loading ||
      _status == MobileAuthStatus.verifying ||
      _isRefreshingProfile ||
      _isLoggingOut;

  Future<void> bootstrap() async {
    _status = MobileAuthStatus.loading;
    _isRefreshingProfile = false;
    _isLoggingOut = false;
    notifyListeners();

    final restoredSession = await _repository.restoreSession();
    _pendingChallenge = null;
    _errorMessage = null;

    if (restoredSession == null) {
      _session = null;
      _status = MobileAuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    final syncResult = await _repository.syncSession(restoredSession);
    if (syncResult is Success<MobileAuthSession?>) {
      _session = syncResult.data;
      _status = _session == null
          ? MobileAuthStatus.unauthenticated
          : MobileAuthStatus.authenticated;
      notifyListeners();
      return;
    }

    _session = restoredSession;
    _status = MobileAuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> requestOtp(String rawPhone) async {
    final validationMessage = validatePhoneInput(rawPhone);
    if (validationMessage != null) {
      _errorMessage = validationMessage;
      _status = MobileAuthStatus.error;
      notifyListeners();
      return;
    }
    final phone = normalizePhone(rawPhone);

    _errorMessage = null;
    _status = MobileAuthStatus.loading;
    _isRefreshingProfile = false;
    _isLoggingOut = false;
    notifyListeners();

    final result = await _repository.requestOtp(phone);

    if (result is Success<OtpChallenge>) {
      _pendingChallenge = result.data;
      _status = MobileAuthStatus.otpRequested;
      notifyListeners();
      return;
    }

    _errorMessage = (result as Failure<OtpChallenge>).message;
    _status = MobileAuthStatus.error;
    notifyListeners();
  }

  Future<void> verifyOtp(String rawCode) async {
    final challenge = _pendingChallenge;
    final code = rawCode.trim();

    if (challenge == null) {
      _errorMessage = 'Сначала запросите код для входа.';
      _status = MobileAuthStatus.error;
      notifyListeners();
      return;
    }

    final validationMessage = validateOtpCode(code);
    if (validationMessage != null) {
      _errorMessage = validationMessage;
      _status = MobileAuthStatus.error;
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _status = MobileAuthStatus.verifying;
    _isRefreshingProfile = false;
    _isLoggingOut = false;
    notifyListeners();

    final result = await _repository.verifyOtp(
      phone: challenge.phone,
      code: code,
      verificationId: challenge.verificationId,
    );

    if (result is Success<MobileAuthSession>) {
      _session = result.data;
      _pendingChallenge = null;
      _status = MobileAuthStatus.authenticated;
      notifyListeners();
      return;
    }

    _errorMessage = (result as Failure<MobileAuthSession>).message;
    _status = MobileAuthStatus.error;
    notifyListeners();
  }

  Future<void> resendOtp() async {
    final challenge = _pendingChallenge;
    if (challenge == null) {
      return;
    }

    await requestOtp(challenge.phone);
  }

  Future<void> refreshProfile() async {
    final session = _session;
    if (session == null || _isRefreshingProfile || _isLoggingOut) {
      return;
    }

    _errorMessage = null;
    _isRefreshingProfile = true;
    notifyListeners();

    final result = await _repository.syncSession(session);

    if (result is Success<MobileAuthSession?>) {
      _session = result.data;
      _pendingChallenge = null;
      _status = _session == null
          ? MobileAuthStatus.unauthenticated
          : MobileAuthStatus.authenticated;
      _isRefreshingProfile = false;
      notifyListeners();
      return;
    }

    _errorMessage = (result as Failure<MobileAuthSession?>).message;
    _status = MobileAuthStatus.error;
    _isRefreshingProfile = false;
    notifyListeners();
  }

  Future<void> logout() async {
    if (_isLoggingOut) {
      return;
    }

    _isLoggingOut = true;
    _errorMessage = null;
    notifyListeners();

    final session = _session;
    final result = session == null
        ? const Success<void>(null)
        : await _repository.logout(session);

    if (result is Failure<void>) {
      _errorMessage = result.message;
      _status = MobileAuthStatus.error;
      _isLoggingOut = false;
      notifyListeners();
      return;
    }

    await _repository.clearSession();
    _session = null;
    _pendingChallenge = null;
    _errorMessage = null;
    _status = MobileAuthStatus.unauthenticated;
    _isRefreshingProfile = false;
    _isLoggingOut = false;
    notifyListeners();
  }

  void editPhone() {
    _pendingChallenge = null;
    _errorMessage = null;
    _status = _session == null
        ? MobileAuthStatus.unauthenticated
        : MobileAuthStatus.authenticated;
    notifyListeners();
  }

  void clearError() {
    if (_status != MobileAuthStatus.error) {
      return;
    }

    _errorMessage = null;
    _status = _session != null
        ? MobileAuthStatus.authenticated
        : _pendingChallenge != null
            ? MobileAuthStatus.otpRequested
            : MobileAuthStatus.unauthenticated;
    notifyListeners();
  }

  String maskPhone(String phone) {
    final normalized = normalizePhone(phone);
    if (normalized.length < 8) {
      return normalized;
    }

    return '${normalized.substring(0, 4)} ${normalized.substring(4, 7)} *** ** ${normalized.substring(normalized.length - 2)}';
  }

  String normalizePhone(String value) {
    return _normalizePhone(value);
  }

  String? validatePhoneInput(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Введите номер телефона.';
    }

    if (!_isValidPhone(_normalizePhone(value!))) {
      return 'Введите номер в формате +7 777 123 45 67.';
    }

    return null;
  }

  String? validateOtpCode(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Введите код из SMS.';
    }

    if (!_isValidCode((value ?? '').trim())) {
      return 'Введите код без лишних символов.';
    }

    return null;
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^\+7\d{10}$').hasMatch(phone);
  }

  bool _isValidCode(String code) {
    return RegExp(r'^\d{4,8}$').hasMatch(code);
  }

  String _normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return '';
    }

    if (digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    } else if (!digits.startsWith('7')) {
      digits = '7$digits';
    }

    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }

    return '+$digits';
  }
}
