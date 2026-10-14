import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/notifications/domain/notification_destination.dart';

class NotificationNavigationCoordinator {
  NotificationNavigationCoordinator._();

  static final instance = NotificationNavigationCoordinator._();

  NavigatorState? _navigator;
  ScaffoldMessengerState? _scaffoldMessenger;
  bool _authenticated = false;
  _PendingNotification? _pending;
  _ForegroundMessage? _pendingForegroundMessage;
  Future<void> Function(String campaignId)? _trackCampaignOpen;

  void configureCampaignOpenTracker(
    Future<void> Function(String campaignId) tracker,
  ) {
    _trackCampaignOpen = tracker;
  }

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
    _pending = _PendingNotification(
      destination: destination,
      campaignId: _campaignId(payload),
    );
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
    final normalizedPayload = <String, dynamic>{
      ...destination.toPayload(),
    };
    final campaignId = _campaignId(payload);
    if (campaignId != null) normalizedPayload['campaignId'] = campaignId;
    _pendingForegroundMessage = _ForegroundMessage(
      title: normalizedTitle?.isNotEmpty == true
          ? normalizedTitle!
          : 'Новое уведомление',
      body: normalizedBody?.isNotEmpty == true ? normalizedBody! : null,
      payload: normalizedPayload,
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
    _trackCampaignOpen = null;
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
    final pending = _pending;
    if (!_authenticated || navigator == null || pending == null) return;
    _pending = null;
    final campaignId = pending.campaignId;
    if (campaignId != null) {
      unawaited(_trackCampaignOpen?.call(campaignId) ?? Future<void>.value());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) {
        navigator.pushNamed(
          pending.destination.routeName,
          arguments: pending.destination.arguments,
        );
      }
    });
    // A payload can arrive before the first authenticated frame. Ensure the
    // post-frame callback is not stranded when no frame is otherwise queued.
    WidgetsBinding.instance.scheduleFrame();
  }

  String? _campaignId(Map<String, dynamic> payload) {
    final value = payload['campaignId'] ?? payload['campaign_id'];
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }
}

class _PendingNotification {
  const _PendingNotification({required this.destination, this.campaignId});

  final NotificationDestination destination;
  final String? campaignId;
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
