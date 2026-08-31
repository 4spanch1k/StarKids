abstract final class AppEnvironment {
  static const appEnv = String.fromEnvironment(
    'MOBILE_APP_ENV',
    defaultValue: 'development',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'MOBILE_API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1/mobile',
  );

  static const clerkPublishableKey = String.fromEnvironment(
    'MOBILE_CLERK_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static bool get hasClerkPublishableKey =>
      clerkPublishableKey.trim().isNotEmpty;

  static const _useMockBirthdayRequests = bool.fromEnvironment(
    'MOBILE_USE_MOCK_BIRTHDAY_REQUESTS',
    defaultValue: false,
  );

  static bool get isDevelopment => appEnv.trim().toLowerCase() == 'development';

  static bool get isTest =>
      appEnv.trim().toLowerCase() == 'test' ||
      appEnv.trim().toLowerCase() == 'testing';

  static bool get allowsDevelopmentFixtures => isDevelopment || isTest;

  static bool get useMockBirthdayRequests =>
      allowsDevelopmentFixtures && _useMockBirthdayRequests;

  static const defaultCity = String.fromEnvironment(
    'MOBILE_DEFAULT_CITY',
    defaultValue: 'Shymkent',
  );
}
