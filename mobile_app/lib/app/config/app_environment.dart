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

  static const googleServerClientId = String.fromEnvironment(
    'MOBILE_GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static const googleIosClientId = String.fromEnvironment(
    'MOBILE_GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static const googleIosReversedClientId = String.fromEnvironment(
    'MOBILE_GOOGLE_IOS_REVERSED_CLIENT_ID',
    defaultValue: '',
  );

  static bool get hasGoogleSignInConfig => isGoogleSignInConfigured(
        platform: defaultTargetPlatform,
        serverClientId: googleServerClientId,
        iosClientId: googleIosClientId,
        iosReversedClientId: googleIosReversedClientId,
      );

  static bool isGoogleSignInConfigured({
    required TargetPlatform platform,
    required String serverClientId,
    required String iosClientId,
    required String iosReversedClientId,
  }) {
    if (serverClientId.trim().isEmpty) {
      return false;
    }
    if (platform == TargetPlatform.iOS) {
      return iosClientId.trim().isNotEmpty &&
          iosReversedClientId.trim().isNotEmpty;
    }
    return true;
  }

  static const _useMockBirthdayRequests = bool.fromEnvironment(
    'MOBILE_USE_MOCK_BIRTHDAY_REQUESTS',
    defaultValue: false,
  );

  static bool get isDevelopment => appEnv.trim().toLowerCase() == 'development';

  static bool get isProduction => appEnv.trim().toLowerCase() == 'production';

  static bool get isTest =>
      appEnv.trim().toLowerCase() == 'test' ||
      appEnv.trim().toLowerCase() == 'testing';

  static const privacyPolicyUrl = String.fromEnvironment(
    'MOBILE_PRIVACY_POLICY_URL',
    defaultValue: '',
  );

  static const privacyConsentVersion = String.fromEnvironment(
    'MOBILE_PRIVACY_CONSENT_VERSION',
    defaultValue: 'v1-pending-legal',
  );

  static void validateReleaseConfiguration() {
    // Accessing apiBaseUrl performs the existing production API validation.
    apiBaseUrl;
    validatePrivacyConfiguration(
      environment: appEnv,
      releaseMode: kReleaseMode,
      configuredUrl: privacyPolicyUrl,
      consentVersion: privacyConsentVersion,
    );
  }

  static void validatePrivacyConfiguration({
    required String environment,
    required bool releaseMode,
    required String configuredUrl,
    required String consentVersion,
  }) {
    final normalizedEnvironment = environment.trim().toLowerCase();
    if (!releaseMode && normalizedEnvironment != 'production') return;

    final uri = Uri.tryParse(configuredUrl.trim());
    final invalidHost = uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == 'example.com' ||
        uri.host.endsWith('.example.com') ||
        uri.host == 'example.org' ||
        uri.host.endsWith('.example.org') ||
        uri.host == 'example.net' ||
        uri.host.endsWith('.example.net') ||
        uri.host.endsWith('.invalid');
    if (invalidHost) {
      throw StateError(
        'MOBILE_PRIVACY_POLICY_URL must be an explicit HTTPS URL in production.',
      );
    }

    final normalizedVersion = consentVersion.trim().toLowerCase();
    if (normalizedVersion.isEmpty ||
        normalizedVersion.contains('pending') ||
        normalizedVersion.contains('placeholder') ||
        normalizedVersion.startsWith('v1-pending-legal')) {
      throw StateError(
        'MOBILE_PRIVACY_CONSENT_VERSION must be an approved version in production.',
      );
    }
  }

  static bool get allowsDevelopmentFixtures => isDevelopment || isTest;

  static bool get useMockBirthdayRequests =>
      allowsDevelopmentFixtures && _useMockBirthdayRequests;

  static const defaultCity = String.fromEnvironment(
    'MOBILE_DEFAULT_CITY',
    defaultValue: 'Shymkent',
  );
}
