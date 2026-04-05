abstract final class AppEnvironment {
  static const appEnv = String.fromEnvironment(
    'MOBILE_APP_ENV',
    defaultValue: 'development',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'MOBILE_API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1/mobile',
  );

  static const defaultCity = String.fromEnvironment(
    'MOBILE_DEFAULT_CITY',
    defaultValue: 'Shymkent',
  );
}

