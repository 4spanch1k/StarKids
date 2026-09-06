// Firebase client options for the approved Boom Bala production project.
// Native Android/iOS resources are kept alongside this file so the platform
// Firebase SDKs and FlutterFire use the same project and application ids.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  /// Placeholder values must never be mistaken for a live Firebase project.
  static bool get isConfigured {
    return isConfiguredFor(currentPlatform);
  }

  /// Allows platform-independent tests to verify real and placeholder configs.
  static bool isConfiguredFor(FirebaseOptions options) {
    final requiredValues = <String?>[
      options.apiKey,
      options.appId,
      options.messagingSenderId,
      options.projectId,
    ];
    if (options.iosBundleId != null) {
      requiredValues.add(options.iosBundleId);
    }
    return !requiredValues.any(_isPlaceholder);
  }

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
          'Configure a client app for this platform before enabling Firebase.',
        ),
    };
  }

  static bool _isPlaceholder(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return normalized.isEmpty ||
        normalized.startsWith('placeholder_') ||
        normalized.contains('placeholder') ||
        normalized.startsWith('com.example.');
  }

  static const FirebaseOptions _android = FirebaseOptions(
    apiKey: 'AIzaSyALN2bMszVgoLffhPEDvMQYgdEQmJvDay8',
    appId: '1:491968637725:android:bb1edec8d77d1dfad04ff4',
    messagingSenderId: '491968637725',
    projectId: 'boom-bala-production',
    storageBucket: 'boom-bala-production.firebasestorage.app',
  );

  static const FirebaseOptions _ios = FirebaseOptions(
    apiKey: 'AIzaSyBloZeoUnUWG_cafGddf3E4RjGVVezTS7U',
    appId: '1:491968637725:ios:35a724b2826b1a40d04ff4',
    messagingSenderId: '491968637725',
    projectId: 'boom-bala-production',
    storageBucket: 'boom-bala-production.firebasestorage.app',
    iosBundleId: 'kz.boombala.app',
  );

  // Desktop/web Firebase apps were not included in the supplied production
  // client configs; those targets remain safely disabled until configured.
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
