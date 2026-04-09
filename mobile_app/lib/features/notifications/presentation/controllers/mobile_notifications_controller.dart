import 'package:flutter/material.dart';

import '../../domain/notification_permission_status.dart';
import '../../domain/notification_settings_repository.dart';

class MobileNotificationsController extends ChangeNotifier
    with WidgetsBindingObserver {
  MobileNotificationsController({
    required NotificationSettingsRepository repository,
  }) : _repository = repository;

  final NotificationSettingsRepository _repository;

  NotificationPermissionStatus _status = NotificationPermissionStatus.unknown;
  bool _isLoading = false;
  bool _isRequestingPermission = false;
  bool _isOpeningSettings = false;
  bool _isBootstrapped = false;
  String? _errorMessage;

  NotificationPermissionStatus get status => _status;

  bool get isLoading => _isLoading;

  bool get isRequestingPermission => _isRequestingPermission;

  bool get isOpeningSettings => _isOpeningSettings;

  String? get errorMessage => _errorMessage;

  bool get isBusy =>
      _isLoading || _isRequestingPermission || _isOpeningSettings;

  Future<void> bootstrap() async {
    if (_isBootstrapped) {
      return;
    }

    _isBootstrapped = true;
    WidgetsBinding.instance.addObserver(this);
    await refreshStatus();
  }

  Future<void> refreshStatus({
    bool showLoading = true,
  }) async {
    if (_isRequestingPermission || _isOpeningSettings) {
      return;
    }

    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      _status = await _repository.loadPermissionStatus();
    } catch (_) {
      _errorMessage = 'Не удалось проверить состояние уведомлений.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestPermission() async {
    if (_isRequestingPermission || _isOpeningSettings) {
      return;
    }

    _isRequestingPermission = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _status = await _repository.requestPermission();
    } catch (_) {
      _errorMessage = 'Не удалось обновить разрешение на уведомления.';
    } finally {
      _isRequestingPermission = false;
      notifyListeners();
    }
  }

  Future<void> openSystemSettings() async {
    if (_isRequestingPermission || _isOpeningSettings) {
      return;
    }

    _isOpeningSettings = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final opened = await _repository.openSystemSettings();
      if (!opened) {
        _errorMessage = 'Не удалось открыть настройки приложения.';
      }
    } catch (_) {
      _errorMessage = 'Не удалось открыть настройки приложения.';
    } finally {
      _isOpeningSettings = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshStatus(showLoading: false);
    }
  }
}
