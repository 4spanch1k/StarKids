import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/bootstrap/star_kids_bootstrap_app.dart';
import 'app/config/app_environment.dart';
import 'app/di/service_registry.dart';
import 'app/router/notification_navigation_coordinator.dart';
import 'firebase_options.dart';

/// FCM background message handler.  Must be a top-level function.
/// Runs in a separate isolate; keep it minimal.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Background messages are received here when the app is terminated or in
  // the background.  Extend this handler to persist the message locally or
  // trigger a local notification via flutter_local_notifications.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[BOOT] main started');

  // Production/release builds must carry an approved, externally hosted
  // privacy policy instead of the development-only pending-legal marker.
  AppEnvironment.validateReleaseConfiguration();

  NotificationNavigationCoordinator.instance.configureCampaignOpenTracker(
    ServiceRegistry.campaignOpenTracker.track,
  );

  runApp(const StarKidsBootstrapApp(initialize: ServiceRegistry.bootstrap));

  // Firebase and its notification listeners are non-critical for the first
  // frame. Start them after Flutter has mounted so a broken/unreachable
  // Firebase runtime cannot hold the splash screen hostage.
  unawaited(
    _initFirebaseSafely().timeout(
      const Duration(seconds: 8),
      onTimeout: () => debugPrint('[BOOT] Firebase init timed out; continuing'),
    ),
  );
}

Future<void> _initFirebaseSafely() async {
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint(
        '[BOOT] Firebase init skipped: no configuration for this target',
      );
      // Resolve the handshake even on unsupported/unconfigured targets so the
      // controller can settle on its safe unavailable state.
      ServiceRegistry.pushTokenController.onPushProviderReady();
      return;
    }

    await Firebase.initializeApp(options: options);

    // Background message handler (app terminated / in background).
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Firebase does not present a system notification consistently while the
    // app is open, so show a visible in-app notification and route its action
    // through the same semantic coordinator as background taps.
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '[FCM] Foreground message: ${message.notification?.title} '
        '— ${message.notification?.body}',
      );
      NotificationNavigationCoordinator.instance.showForegroundMessage(
        title: message.notification?.title,
        body: message.notification?.body,
        payload: message.data,
      );
    });

    // Tap on notification while app is in the background (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] Opened via notification tap: ${message.data}');
      NotificationNavigationCoordinator.instance.handlePayload(message.data);
    });

    // Firebase is initialized and its message listeners are active. The push
    // controller can now subscribe to token refresh and retry registration for
    // an authenticated, completed-onboarding account.
    ServiceRegistry.pushTokenController.onPushProviderReady();

    // Check if the app was launched from a terminated state via notification tap.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '[FCM] App launched from terminated notification: ${initialMessage.data}',
      );
      NotificationNavigationCoordinator.instance.handlePayload(
        initialMessage.data,
      );
    }
  } catch (_) {
    debugPrint('[BOOT] Firebase init skipped');
    // Firebase unavailable for this target; core app flows remain usable.
  }
}
