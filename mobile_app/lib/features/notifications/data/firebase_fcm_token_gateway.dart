import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'fcm_token_gateway.dart';

/// Obtains FCM tokens via [FirebaseMessaging].
///
/// Returns [null] from [getToken] when:
/// - Firebase has not been initialized (no [firebase_options.dart] configured).
/// - The platform is unsupported (Linux, Windows).
/// - Any other unexpected error occurs.
///
/// The [onTokenRefresh] stream is a thin wrapper around
/// [FirebaseMessaging.instance.onTokenRefresh].
class FirebaseFcmTokenGateway implements FcmTokenGateway {
  @override
  Future<String?> getToken() async {
    if (!_isSupportedPlatform) {
      return null;
    }

    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[FirebaseFcmTokenGateway] getToken failed: $e');
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh {
    if (!_isSupportedPlatform) {
      return const Stream.empty();
    }

    try {
      return FirebaseMessaging.instance.onTokenRefresh;
    } catch (e) {
      debugPrint('[FirebaseFcmTokenGateway] onTokenRefresh unavailable: $e');
      return const Stream.empty();
    }
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      _ => false,
    };
  }
}
