// IMPORTANT: This file is a placeholder.
//
// To enable real Firebase push notifications, run:
//   flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
//
// That command will overwrite this file with real Firebase configuration and
// will also generate:
//   - android/app/google-services.json
//   - ios/Runner/GoogleService-Info.plist (when iOS target is added)
//
// Until then, Firebase.initializeApp() will throw and the app will start
// without push notification capability. All other features remain unaffected.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return _web;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _android,
      TargetPlatform.iOS => _ios,
      TargetPlatform.macOS => _macos,
      _ => throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.\n'
          'Run: flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID',
        ),
    };
  }

  // ---------------------------------------------------------------------------
  // Placeholder values — replace by running: flutterfire configure
  // ---------------------------------------------------------------------------

  static const FirebaseOptions _android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: 'PLACEHOLDER_APP_ID',
    messagingSenderId: 'PLACEHOLDER_SENDER_ID',
    projectId: 'PLACEHOLDER_PROJECT_ID',
  );

  static const FirebaseOptions _ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: 'PLACEHOLDER_APP_ID',
    messagingSenderId: 'PLACEHOLDER_SENDER_ID',
    projectId: 'PLACEHOLDER_PROJECT_ID',
    iosBundleId: 'com.example.starKidsMobile',
  );

  static const FirebaseOptions _macos = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: 'PLACEHOLDER_APP_ID',
    messagingSenderId: 'PLACEHOLDER_SENDER_ID',
    projectId: 'PLACEHOLDER_PROJECT_ID',
    iosBundleId: 'com.example.starKidsMobile',
  );

  static const FirebaseOptions _web = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: 'PLACEHOLDER_APP_ID',
    messagingSenderId: 'PLACEHOLDER_SENDER_ID',
    projectId: 'PLACEHOLDER_PROJECT_ID',
  );
}
