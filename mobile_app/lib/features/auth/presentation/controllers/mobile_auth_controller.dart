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

class MobileAuthCancelledException implements Exception {
  const MobileAuthCancelledException();
}

class MobileAuthFlowException implements Exception {
  const MobileAuthFlowException(this.message);

  final String message;
}

class MobileAuthController extends ChangeNotifier {
  MobileAuthController({
    required MobileAuthRepository repository,
  }) : _repository = repository;

  final MobileAuthRepository _repository;
  static const _bootstrapTimeout = Duration(seconds: 8);

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

  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) {
    return _authenticateWithEmail(
      _repository.registerWithEmail(
        email: _normalizeEmail(email),
        password: password,
      ),
    );
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) {
    return _authenticateWithEmail(
      _repository.loginWithEmail(
        email: _normalizeEmail(email),
        password: password,
      ),
    );
  }

  Future<void> loginWithGoogleClerk({
    required Future<String> Function() requestSessionToken,
  }) async {
    if (isBusy) {
      return;
    }
    _errorMessage = null;
    _pendingChallenge = null;
    _status = MobileAuthStatus.loading;
    _isRefreshingProfile = false;
    _isLoggingOut = false;
    notifyListeners();

    try {
      final sessionToken = (await requestSessionToken()).trim();
      if (sessionToken.isEmpty) {
        _session = null;
        _errorMessage = 'Не удалось получить сессию Google. Попробуйте снова.';
        _status = MobileAuthStatus.error;
        notifyListeners();
        return;
      }

      final result = await _repository.exchangeClerkSession(
        sessionToken: sessionToken,
      );

      if (result is Success<MobileAuthSession>) {
        _session = result.data;
        _status = MobileAuthStatus.authenticated;
        notifyListeners();
        return;
      }

      _session = null;
      _errorMessage = (result as Failure<MobileAuthSession>).message;
      _status = MobileAuthStatus.error;
      notifyListeners();
    } on MobileAuthCancelledException {
      _session = null;
      _errorMessage = null;
      _status = MobileAuthStatus.idle;
      notifyListeners();
    } on MobileAuthFlowException catch (error) {
      _session = null;
      _errorMessage = error.message;
      _status = MobileAuthStatus.error;
      notifyListeners();
    } catch (_) {
      _session = null;
      _errorMessage = 'Не удалось войти через Google. Попробуйте снова.';
      _status = MobileAuthStatus.error;
      notifyListeners();
    }
  }

  Future<void> bootstrap() async {
    debugPrint('[AUTH] bootstrap started');
    _status = MobileAuthStatus.loading;
    _isRefreshingProfile = false;
    _isLoggingOut = false;
    notifyListeners();

    try {
      debugPrint('[AUTH] session storage read started');
      final restoredSession =
          await _repository.restoreSession().timeout(_bootstrapTimeout);
      debugPrint(
        '[AUTH] session storage result: hasSession=${restoredSession != null}',
      );
      _pendingChallenge = null;
      _errorMessage = null;

      if (restoredSession == null) {
        _session = null;
        debugPrint('[AUTH] state -> unauthenticated');
        _status = MobileAuthStatus.unauthenticated;
        return;
      }

      debugPrint('[AUTH] current-user sync started');
      final syncResult = await _repository
          .syncSession(restoredSession)
          .timeout(_bootstrapTimeout);
      if (syncResult is Success<MobileAuthSession?>) {
        _session = syncResult.data;
        _status = _session == null
            ? MobileAuthStatus.unauthenticated
            : MobileAuthStatus.authenticated;
        debugPrint(
          _session == null
              ? '[AUTH] current-user sync returned no session'
              : '[AUTH] current-user sync success',
        );
        debugPrint(
          _session == null
              ? '[AUTH] state -> unauthenticated'
              : '[AUTH] state -> authenticated',
        );
        return;
      }

      debugPrint(
        '[AUTH] current-user sync failed: '
        '${(syncResult as Failure<MobileAuthSession?>).message}',
      );
      await _safeClearSession();
      _session = null;
      _pendingChallenge = null;
      _errorMessage = null;
      _status = MobileAuthStatus.unauthenticated;
      debugPrint('[AUTH] state -> unauthenticated');
    } catch (error) {
      debugPrint('[AUTH] bootstrap failed: $error');
      await _safeClearSession();
      _session = null;
      _pendingChallenge = null;
      _errorMessage = null;
      _status = MobileAuthStatus.unauthenticated;
      debugPrint('[AUTH] state -> unauthenticated');
    } finally {
      _isRefreshingProfile = false;
      _isLoggingOut = false;
      debugPrint('[AUTH] bootstrap finally loading=false');
      notifyListeners();
    }
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

  Future<void> _authenticateWithEmail(
    Future<Result<MobileAuthSession>> request,
  ) async {
    _errorMessage = null;
    _pendingChallenge = null;
    _status = MobileAuthStatus.loading;
    _isRefreshingProfile = false;
    _isLoggingOut = false;
    notifyListeners();

    try {
      final result = await request;

      if (result is Success<MobileAuthSession>) {
        _session = result.data;
        _status = MobileAuthStatus.authenticated;
        notifyListeners();
        return;
      }

      _session = null;
      _errorMessage = (result as Failure<MobileAuthSession>).message;
      _status = MobileAuthStatus.error;
      notifyListeners();
    } catch (_) {
      _session = null;
      _errorMessage =
          'Не удалось войти. Проверьте интернет и попробуйте снова.';
      _status = MobileAuthStatus.error;
      notifyListeners();
    }
  }

  Future<void> _safeClearSession() async {
    try {
      debugPrint('[AUTH] clear session');
      await _repository.clearSession().timeout(_bootstrapTimeout);
    } catch (error) {
      debugPrint('[AUTH] clear session failed: $error');
    }
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

  String? validateEmailInput(String? value) {
    final email = _normalizeEmail(value ?? '');
    if (email.isEmpty) {
      return 'Введите электронную почту.';
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Введите корректную электронную почту.';
    }

    return null;
  }

  String? validatePasswordInput(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Введите пароль.';
    }

    if (password.length < 8) {
      return 'Пароль должен быть не короче 8 символов.';
    }

    return null;
  }

  String? validatePasswordConfirmation({
    required String? password,
    required String? confirmation,
  }) {
    final repeatedPassword = confirmation ?? '';
    if (repeatedPassword.isEmpty) {
      return 'Повторите пароль.';
    }

    if (repeatedPassword.length < 8) {
      return 'Пароль должен быть не короче 8 символов.';
    }

    if ((password ?? '') != repeatedPassword) {
      return 'Пароли не совпадают.';
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

  String _normalizeEmail(String value) {
    return value.trim().toLowerCase();
  }
}
