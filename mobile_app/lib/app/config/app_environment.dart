import 'package:flutter/foundation.dart';

abstract final class AppEnvironment {
  static const appEnv = String.fromEnvironment(
    'MOBILE_APP_ENV',
    defaultValue: 'development',
  );

  static const _configuredApiBaseUrl = String.fromEnvironment(
    'MOBILE_API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    return validateApiBaseUrl(
      environment: appEnv,
      configuredApiBaseUrl: _configuredApiBaseUrl,
      releaseMode: kReleaseMode,
    );
  }

  static String validateApiBaseUrl({
    required String environment,
    required String configuredApiBaseUrl,
    required bool releaseMode,
  }) {
    final normalizedEnvironment = environment.trim().toLowerCase();
    final configured = configuredApiBaseUrl.trim();

    if (releaseMode && normalizedEnvironment != 'production') {
      throw StateError(
        'MOBILE_APP_ENV must be production in Flutter release mode.',
      );
    }

    if (releaseMode || normalizedEnvironment == 'production') {
      final uri = Uri.tryParse(configured);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw StateError(
          'MOBILE_API_BASE_URL must be an explicit HTTPS URL in production.',
        );
      }
      final host = uri.host.toLowerCase();
      if (host == 'localhost' ||
          host == '127.0.0.1' ||
          host.endsWith('.invalid')) {
        throw StateError(
          'MOBILE_API_BASE_URL cannot point to localhost or a placeholder host in production.',
        );
      }
      return configured;
    }

    return configured.isEmpty
        ? 'http://localhost:8000/api/v1/mobile'
        : configured;
  }

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

  static bool get isProduction => appEnv.trim().toLowerCase() == 'production';

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
