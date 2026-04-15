/// Lifecycle status of the FCM push token registration with the backend.
enum PushRegistrationStatus {
  /// Registration has not been attempted yet (initial state).
  idle,

  /// Currently fetching the FCM token or communicating with the backend.
  registering,

  /// Token successfully registered with the backend.
  registered,

  /// Registration failed.  A [retryAfterLogin] or [retryAfterPermission]
  /// path may apply depending on the cause.
  failed,

  /// Push permission was denied by the user.  No token is available.
  permissionDenied,

  /// Firebase is not initialized or the platform does not support FCM.
  /// This is an external blocker — see [firebase_options.dart].
  unavailable,

  /// The user is not authenticated.  Token registration will be retried
  /// automatically when they log in.
  unauthenticated,
}
