import 'package:flutter/foundation.dart';

import '../features/children/presentation/controllers/children_controller.dart';
import '../features/profile/presentation/controllers/profile_controller.dart';

typedef AccountIdentityReader = String? Function();

/// Invalidates shared family state whenever the authenticated account changes.
///
/// This small lifecycle helper deliberately owns no app state of its own. It
/// only observes the existing auth notifier and delegates the reset to the
/// account-scoped controllers, keeping logout/account-switch cleanup out of
/// individual pages.
class AccountStateCoordinator {
  AccountStateCoordinator({
    required Listenable authListenable,
    required AccountIdentityReader readIdentity,
    required ProfileController profileController,
    required ChildrenController childrenController,
  })  : _authListenable = authListenable,
        _readIdentity = readIdentity,
        _profileController = profileController,
        _childrenController = childrenController,
        _lastIdentity = readIdentity() {
    _authListenable.addListener(_handleAuthChanged);
  }

  final Listenable _authListenable;
  final AccountIdentityReader _readIdentity;
  final ProfileController _profileController;
  final ChildrenController _childrenController;
  String? _lastIdentity;

  void _handleAuthChanged() {
    final nextIdentity = _readIdentity();
    if (nextIdentity == _lastIdentity) {
      return;
    }

    _lastIdentity = nextIdentity;
    _profileController.resetForAccountChange();
    _childrenController.resetForAccountChange();
  }

  void dispose() {
    _authListenable.removeListener(_handleAuthChanged);
  }
}
