import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/app/config/app_environment.dart';

void main() {
  test('birthday requests use the live backend by default', () {
    expect(AppEnvironment.useMockBirthdayRequests, isFalse);
  });

  test('debug development keeps the localhost fallback', () {
    expect(
      AppEnvironment.validateApiBaseUrl(
        environment: 'development',
        configuredApiBaseUrl: '',
        releaseMode: false,
      ),
      'http://localhost:8000/api/v1/mobile',
    );
  });

  test('release development environment fails closed', () {
    expect(
      () => AppEnvironment.validateApiBaseUrl(
        environment: 'development',
        configuredApiBaseUrl: 'https://api.example-valid-host.kz/api/v1/mobile',
        releaseMode: true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('release production requires explicit HTTPS API URL', () {
    expect(
      () => AppEnvironment.validateApiBaseUrl(
        environment: 'production',
        configuredApiBaseUrl: '',
        releaseMode: true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('release production rejects localhost and placeholder hosts', () {
    for (final url in [
      'http://localhost:8000/api/v1/mobile',
      'https://127.0.0.1/api/v1/mobile',
      'https://api.example.invalid/api/v1/mobile',
    ]) {
      expect(
        () => AppEnvironment.validateApiBaseUrl(
          environment: 'production',
          configuredApiBaseUrl: url,
          releaseMode: true,
        ),
        throwsA(isA<StateError>()),
      );
    }
  });

  test('production accepts an explicit HTTPS API URL', () {
    const url = 'https://api.example-valid-host.kz/api/v1/mobile';
    expect(
      AppEnvironment.validateApiBaseUrl(
        environment: 'production',
        configuredApiBaseUrl: url,
        releaseMode: true,
      ),
      url,
    );
  });

  test('development allows the pending legal configuration', () {
    expect(
      () => AppEnvironment.validatePrivacyConfiguration(
        environment: 'development',
        releaseMode: false,
        configuredUrl: '',
        consentVersion: 'v1-pending-legal',
      ),
      returnsNormally,
    );
  });

  test('production requires an approved privacy policy URL and version', () {
    expect(
      () => AppEnvironment.validatePrivacyConfiguration(
        environment: 'production',
        releaseMode: true,
        configuredUrl: '',
        consentVersion: 'v1-pending-legal',
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => AppEnvironment.validatePrivacyConfiguration(
        environment: 'production',
        releaseMode: true,
        configuredUrl: 'https://boom-bala.kz/privacy',
        consentVersion: 'v1-pending-legal',
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => AppEnvironment.validatePrivacyConfiguration(
        environment: 'production',
        releaseMode: true,
        configuredUrl: 'https://boom-bala.kz/privacy',
        consentVersion: '2026-01',
      ),
      returnsNormally,
    );
  });

  test('iOS Google Sign-In requires native client and reversed URL config', () {
    expect(
      AppEnvironment.isGoogleSignInConfigured(
        platform: TargetPlatform.iOS,
        serverClientId: 'web-client-id',
        iosClientId: '',
        iosReversedClientId: 'reversed-client-id',
      ),
      isFalse,
    );
    expect(
      AppEnvironment.isGoogleSignInConfigured(
        platform: TargetPlatform.iOS,
        serverClientId: 'web-client-id',
        iosClientId: 'ios-client-id',
        iosReversedClientId: '',
      ),
      isFalse,
    );
    expect(
      AppEnvironment.isGoogleSignInConfigured(
        platform: TargetPlatform.iOS,
        serverClientId: 'web-client-id',
        iosClientId: 'ios-client-id',
        iosReversedClientId: 'reversed-client-id',
      ),
      isTrue,
    );
  });

  test('Google Sign-In always requires the Web/server client ID', () {
    expect(
      AppEnvironment.isGoogleSignInConfigured(
        platform: TargetPlatform.android,
        serverClientId: '',
        iosClientId: 'ios-client-id',
        iosReversedClientId: 'reversed-client-id',
      ),
      isFalse,
    );
  });
}
