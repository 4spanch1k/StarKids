import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/core/api/api_client.dart';
import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/auth/data/mobile_auth_session_storage.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_repository.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_session.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_user.dart';
import 'package:star_kids_mobile/features/auth/domain/otp_challenge.dart';
import 'package:star_kids_mobile/features/profile/data/api_profile_repository.dart';
import 'package:star_kids_mobile/features/profile/domain/user_profile.dart';

void main() {
  group('ApiProfileRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns failure when there is no stored session', () async {
      final repository = ApiProfileRepository(
        apiClient: ApiClient(
          baseUrl: 'http://example.com',
          httpClient: MockClient((_) async => http.Response('', 500)),
        ),
        sessionStorage: MobileAuthSessionStorage(),
        authRepository: _FakeMobileAuthRepository(),
      );

      final result = await repository.fetchProfile();

      expect(result, isA<Failure<UserProfile>>());
    });

    test('returns profile on 401 after syncing session and retrying', () async {
      var requestCount = 0;
      final sessionStorage = MobileAuthSessionStorage();
      final initialSession = MobileAuthSession(
        user: const MobileAuthUser(id: 'user-1', phone: '+77071234567'),
        phone: '+77071234567',
        accessToken: 'expired-access',
        refreshToken: 'refresh-token',
        tokenType: 'bearer',
        verifiedAt: DateTime.parse('2026-04-10T01:00:00Z'),
      );
      final refreshedSession = initialSession.copyWith(
        accessToken: 'fresh-access',
      );
      await sessionStorage.saveSession(initialSession);

      final repository = ApiProfileRepository(
        apiClient: ApiClient(
          baseUrl: 'http://example.com',
          httpClient: MockClient((request) async {
            requestCount += 1;
            if (requestCount == 1) {
              expect(
                request.headers['Authorization'],
                'Bearer expired-access',
              );
              return http.Response('', 401);
            }

            expect(request.headers['Authorization'], 'Bearer fresh-access');
            return http.Response(
              jsonEncode({
                'id': 'user-1',
                'phone': null,
                'email': 'user@example.com',
                'firstName': 'Иван',
                'lastName': 'Иванов',
                'avatarUrl': null,
                'childBirthDate': null,
              }),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }),
        ),
        sessionStorage: sessionStorage,
        authRepository: _FakeMobileAuthRepository(
          syncSessionResult: Success<MobileAuthSession?>(refreshedSession),
        ),
      );

      final result = await repository.fetchProfile();

      expect(result, isA<Success<UserProfile>>());
      final profile = (result as Success<UserProfile>).data;
      expect(profile.id, 'user-1');
      expect(profile.firstName, 'Иван');
      expect(profile.email, 'user@example.com');
      expect(requestCount, 2);
    });
  });
}

class _FakeMobileAuthRepository implements MobileAuthRepository {
  _FakeMobileAuthRepository({
    this.syncSessionResult = const Success<MobileAuthSession?>(null),
  });

  final Result<MobileAuthSession?> syncSessionResult;

  @override
  Future<void> clearSession() async {}

  @override
  Future<Result<MobileAuthUser>> getCurrentUser(String accessToken) async {
    return const Failure<MobileAuthUser>('not used');
  }

  @override
  Future<Result<MobileAuthSession>> exchangeClerkSession({
    required String sessionToken,
  }) async {
    return const Failure<MobileAuthSession>('not used');
  }

  @override
  Future<Result<void>> logout(MobileAuthSession session) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<MobileAuthSession>> refreshSession(String refreshToken) async {
    return const Failure<MobileAuthSession>('not used');
  }

  @override
  Future<Result<MobileAuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) async {
    return const Failure<MobileAuthSession>('not used');
  }

  @override
  Future<Result<MobileAuthSession>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return const Failure<MobileAuthSession>('not used');
  }

  @override
  Future<Result<OtpChallenge>> requestOtp(String phone) async {
    return const Failure<OtpChallenge>('not used');
  }

  @override
  Future<MobileAuthSession?> restoreSession() async {
    return null;
  }

  @override
  Future<Result<MobileAuthSession?>> syncSession(
    MobileAuthSession session,
  ) async {
    return syncSessionResult;
  }

  @override
  Future<Result<MobileAuthSession>> verifyOtp({
    required String phone,
    required String code,
    required String verificationId,
  }) async {
    return const Failure<MobileAuthSession>('not used');
  }
}
