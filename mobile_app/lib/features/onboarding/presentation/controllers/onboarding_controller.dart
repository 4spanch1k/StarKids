import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/result.dart';
import '../../../auth/presentation/controllers/mobile_auth_controller.dart';
import '../../../profile/domain/user_profile.dart';
import '../../domain/onboarding_completion.dart';
import '../../domain/onboarding_repository.dart';

enum OnboardingStatus { idle, loading, required, complete, submitting, error }

class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required MobileAuthController authController,
    required OnboardingRepository repository,
  })  : _authController = authController,
        _repository = repository {
    _authController.addListener(_handleAuthChanged);
    if (_authController.isAuthenticated) {
      unawaited(load());
    }
  }

  final MobileAuthController _authController;
  final OnboardingRepository _repository;

  OnboardingStatus _status = OnboardingStatus.idle;
  String? _errorMessage;
  OnboardingCompletion? _completion;
  bool _requestInFlight = false;
  String? _loadedAccountId;

  OnboardingStatus get status => _status;
  String? get errorMessage => _errorMessage;
  OnboardingCompletion? get completion => _completion;
  bool get isRequired => _status == OnboardingStatus.required;
  bool get isComplete => _status == OnboardingStatus.complete;
  bool get isLoading => _status == OnboardingStatus.loading;
  bool get isSubmitting => _status == OnboardingStatus.submitting;

  Future<void> load() async {
    if (!_authController.isAuthenticated || _requestInFlight) return;
    final requestedAccountId = _accountId;
    _requestInFlight = true;
    _status = OnboardingStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.fetchProfile();
      // An account transition can happen while the request is in flight.
      // Never apply the previous account's response to the new session.
      if (!_authController.isAuthenticated ||
          _accountId != requestedAccountId) {
        return;
      }
      if (result is Success<UserProfile>) {
        final profile = result.data;
        _loadedAccountId = requestedAccountId;
        _status = profile.onboardingCompleted
            ? OnboardingStatus.complete
            : OnboardingStatus.required;
      } else {
        _status = OnboardingStatus.error;
        _errorMessage = (result as Failure<UserProfile>).message;
      }
    } catch (_) {
      _status = OnboardingStatus.error;
      _errorMessage = 'Не удалось загрузить профиль. Попробуйте снова.';
    } finally {
      _requestInFlight = false;
      notifyListeners();
      if (_authController.isAuthenticated && _accountId != requestedAccountId) {
        unawaited(load());
      }
    }
  }

  Future<bool> complete({
    required String firstName,
    required List<OnboardingChildDraft> children,
    required String privacyConsentVersion,
  }) async {
    if (_requestInFlight) return false;
    _requestInFlight = true;
    _status = OnboardingStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.complete(
        firstName: firstName,
        children: children,
        privacyConsentVersion: privacyConsentVersion,
      );
      if (result is Success<OnboardingCompletion>) {
        _completion = result.data;
        _loadedAccountId = _accountId;
        _status = OnboardingStatus.complete;
        return true;
      }
      _status = OnboardingStatus.required;
      _errorMessage = (result as Failure).message;
      return false;
    } catch (_) {
      _status = OnboardingStatus.required;
      _errorMessage = 'Не удалось сохранить профиль. Попробуйте снова.';
      return false;
    } finally {
      _requestInFlight = false;
      notifyListeners();
    }
  }

  Future<void> retry() => load();

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _handleAuthChanged() {
    if (!_authController.isAuthenticated) {
      _requestInFlight = false;
      _completion = null;
      _loadedAccountId = null;
      _errorMessage = null;
      _status = OnboardingStatus.idle;
      notifyListeners();
      return;
    }
    if (_accountId != _loadedAccountId) {
      _completion = null;
    }
    if (_accountId != _loadedAccountId ||
        _status == OnboardingStatus.idle ||
        _status == OnboardingStatus.error) {
      unawaited(load());
    }
  }

  String? get _accountId {
    final session = _authController.session;
    return session?.user?.id ?? session?.email ?? session?.phone;
  }

  @override
  void dispose() {
    _authController.removeListener(_handleAuthChanged);
    super.dispose();
  }
}
