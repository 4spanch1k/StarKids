/// Repository for registering and removing FCM device tokens with the backend.
abstract class PushTokenRepository {
  /// Sends the FCM [token] to the backend, associating it with the current
  /// authenticated session.
  ///
  /// Returns [true] when the backend accepted the registration.
  Future<bool> registerToken({
    required String token,
    required String platform,
    required String permissionStatus,
    required String accessToken,
  });

  /// Asks the backend to deactivate the device token for the current session.
  /// Best-effort: errors are silently ignored (the token expires naturally).
  Future<void> removeToken({required String accessToken});
}
