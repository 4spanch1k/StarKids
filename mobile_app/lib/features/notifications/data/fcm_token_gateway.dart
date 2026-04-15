/// Abstract gateway for obtaining and refreshing FCM device tokens.
///
/// The concrete implementation ([FirebaseFcmTokenGateway]) requires Firebase
/// to be initialized.  In tests, inject a fake implementation directly.
abstract class FcmTokenGateway {
  /// Returns the current FCM registration token, or [null] if Firebase is not
  /// initialized, the platform is unsupported, or the token could not be
  /// obtained.
  Future<String?> getToken();

  /// Emits a new token whenever FCM rotates the device registration token.
  /// Subscribers should re-register the new token with the backend immediately.
  Stream<String> get onTokenRefresh;
}
