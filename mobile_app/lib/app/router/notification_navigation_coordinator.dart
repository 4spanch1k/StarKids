import 'package:flutter/material.dart';

import '../../features/notifications/domain/notification_destination.dart';

class NotificationNavigationCoordinator {
  NotificationNavigationCoordinator._();

  static final instance = NotificationNavigationCoordinator._();

  NavigatorState? _navigator;
  ScaffoldMessengerState? _scaffoldMessenger;
  bool _authenticated = false;
  NotificationDestination? _pending;
  _ForegroundMessage? _pendingForegroundMessage;

  void attach({
    required NavigatorState navigator,
    required bool authenticated,
    ScaffoldMessengerState? scaffoldMessenger,
  }) {
    _navigator = navigator;
    _scaffoldMessenger = scaffoldMessenger;
    _authenticated = authenticated;
    _flush();
    _flushForegroundMessage();
  }

  void handlePayload(Map<String, dynamic> payload) {
    final destination = NotificationDestination.fromPayload(payload) ??
        const NotificationDestination(type: NotificationDestinationType.home);
    _pending = destination;
    _flush();
  }

  /// Shows an in-app foreground notification without creating a second
  /// navigation/payload path. The action uses [handlePayload], preserving the
  /// existing authentication and onboarding guards.
  void showForegroundMessage({
    required String? title,
    required String? body,
    required Map<String, dynamic> payload,
  }) {
    final normalizedTitle = title?.trim();
    final normalizedBody = body?.trim();
    final destination = NotificationDestination.fromPayload(payload) ??
        const NotificationDestination(type: NotificationDestinationType.home);
    _pendingForegroundMessage = _ForegroundMessage(
      title: normalizedTitle?.isNotEmpty == true
          ? normalizedTitle!
          : 'Новое уведомление',
      body: normalizedBody?.isNotEmpty == true ? normalizedBody! : null,
      payload: destination.toPayload(),
    );
    _flushForegroundMessage();
  }

  @visibleForTesting
  void resetForTesting() {
    _navigator = null;
    _scaffoldMessenger = null;
    _authenticated = false;
    _pending = null;
    _pendingForegroundMessage = null;
  }

  void _flushForegroundMessage() {
    final messenger = _scaffoldMessenger;
    final message = _pendingForegroundMessage;
    if (messenger == null || message == null) return;

    _pendingForegroundMessage = null;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (message.body != null)
                Text(
                  message.body!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          action: SnackBarAction(
            label: 'Открыть',
            onPressed: () => handlePayload(message.payload),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  void _flush() {
    final navigator = _navigator;
    final destination = _pending;
    if (!_authenticated || navigator == null || destination == null) return;
    _pending = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) {
        navigator.pushNamed(
          destination.routeName,
          arguments: destination.arguments,
        );
      }
    });
    // A payload can arrive before the first authenticated frame. Ensure the
    // post-frame callback is not stranded when no frame is otherwise queued.
    WidgetsBinding.instance.scheduleFrame();
  }
}

class _ForegroundMessage {
  const _ForegroundMessage({
    required this.title,
    required this.body,
    required this.payload,
  });

  final String title;
  final String? body;
  final Map<String, dynamic> payload;
}
