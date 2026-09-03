import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/bootstrap/star_kids_bootstrap_app.dart';
import 'app/di/service_registry.dart';
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

  // Attempt Firebase initialization.  This will fail until the project is
  // configured with real credentials (run: flutterfire configure).
  // The app starts normally even when Firebase is unavailable — push
  // notifications are silently disabled in that case.
  await _initFirebaseSafely();
  debugPrint('[BOOT] Firebase init completed or skipped');

  runApp(
    const StarKidsBootstrapApp(
      initialize: ServiceRegistry.bootstrap,
    ),
  );
}

Future<void> _initFirebaseSafely() async {
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.appId == 'PLACEHOLDER_APP_ID' ||
        options.projectId == 'PLACEHOLDER_PROJECT_ID') {
      debugPrint('[BOOT] Firebase init skipped: placeholder configuration');
      return;
    }

    await Firebase.initializeApp(
      options: options,
    );

    // Background message handler (app terminated / in background).
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Foreground message listener (app is open and running).
    // Extend this to show a local notification via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '[FCM] Foreground message: ${message.notification?.title} '
        '— ${message.notification?.body}',
      );
    });

    // Tap on notification while app is in the background (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
        '[FCM] Opened via notification tap: ${message.data}',
      );
      // TODO: Navigate to the relevant screen based on message.data['event'].
    });

    // Check if the app was launched from a terminated state via notification tap.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '[FCM] App launched from terminated notification: ${initialMessage.data}',
      );
      // TODO: Navigate to the relevant screen based on initialMessage.data['event'].
    }
  } catch (_) {
    debugPrint('[BOOT] Firebase init skipped');
    // Firebase not configured — see lib/firebase_options.dart for instructions.
  }
}
