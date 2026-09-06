import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/bootstrap/star_kids_bootstrap_app.dart';
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

  // Firebase is configured for the approved Android/iOS production app ids.
  // Runtime initialization remains best-effort so core app flows still start
  // if a device or deployment has no usable Firebase runtime configuration.
  await _initFirebaseSafely();
  debugPrint('[BOOT] Firebase init completed or skipped');

  runApp(const StarKidsBootstrapApp(initialize: ServiceRegistry.bootstrap));
}

Future<void> _initFirebaseSafely() async {
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint('[BOOT] Firebase init skipped: no configuration for this target');
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
