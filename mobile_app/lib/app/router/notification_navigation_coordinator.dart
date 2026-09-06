import 'package:flutter/material.dart';

import '../../features/notifications/domain/notification_destination.dart';

class NotificationNavigationCoordinator {
  NotificationNavigationCoordinator._();

  static final instance = NotificationNavigationCoordinator._();

  NavigatorState? _navigator;
  bool _authenticated = false;
  NotificationDestination? _pending;

  void attach(
      {required NavigatorState navigator, required bool authenticated}) {
    _navigator = navigator;
    _authenticated = authenticated;
    _flush();
  }

  void handlePayload(Map<String, dynamic> payload) {
    final destination = NotificationDestination.fromPayload(payload);
    if (destination == null) return;
    _pending = destination;
    _flush();
  }

  @visibleForTesting
  void resetForTesting() {
    _navigator = null;
    _authenticated = false;
    _pending = null;
  }

  void _flush() {
    final navigator = _navigator;
    final destination = _pending;
    if (!_authenticated || navigator == null || destination == null) return;
    _pending = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) {
        navigator.pushNamed(destination.routeName,
            arguments: destination.arguments);
      }
    });
    // A payload can arrive before the first authenticated frame. Ensure the
    // post-frame callback is not stranded when no frame is otherwise queued.
    WidgetsBinding.instance.scheduleFrame();
  }
}
