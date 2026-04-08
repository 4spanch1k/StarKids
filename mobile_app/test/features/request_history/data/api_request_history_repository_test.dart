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
import 'package:star_kids_mobile/features/request_history/data/api_request_history_repository.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_item.dart';
import 'package:star_kids_mobile/features/request_history/domain/request_history_repository.dart';

void main() {
  group('ApiRequestHistoryRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns unauthenticated when there is no stored mobile session',
        () async {
      final repository = ApiRequestHistoryRepository(
        apiClient: ApiClient(
          baseUrl: 'http://example.com',
          httpClient: MockClient((_) async => http.Response('', 500)),
        ),
        sessionStorage: MobileAuthSessionStorage(),
        authRepository: _FakeMobileAuthRepository(),
      );

      final result = await repository.fetchMyRequests();

      expect(result, isA<RequestHistoryFetchUnauthenticated>());
    });

    test('refreshes the session after 401 and maps the history response',
        () async {
      var requestCount = 0;
      final sessionStorage = MobileAuthSessionStorage();
      final initialSession = MobileAuthSession(
        user: const MobileAuthUser(
          id: 'user-1',
          phone: '+77071234567',
        ),
        phone: '+77071234567',
        accessToken: 'expired-access',
        refreshToken: 'refresh-token',
        tokenType: 'bearer',
        verifiedAt: DateTime.parse('2026-04-09T01:00:00Z'),
      );
      final refreshedSession = initialSession.copyWith(
        accessToken: 'fresh-access',
      );
      await sessionStorage.saveSession(initialSession);

      final repository = ApiRequestHistoryRepository(
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
                'items': [
                  {
                    'id': 'request-1',
                    'type': 'birthday_request',
                    'status': 'new',
                    'createdAt': '2026-04-09T10:00:00Z',
                    'requestedDate': '2026-04-11',
                    'guestCount': 12,
                    'notes': 'Нужен аниматор',
                    'branch': {
                      'id': 'branch-main',
                      'name': 'Star Kids Main',
                      'shortLabel': 'Main',
                    },
                    'package': {
                      'id': 'package-main',
                      'name': 'Spark Party',
                    },
                  },
                ],
                'total': 1,
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

      final result = await repository.fetchMyRequests();

      expect(result, isA<RequestHistoryFetchSuccess>());
      final success = result as RequestHistoryFetchSuccess;
      expect(success.total, 1);
      expect(success.items.single.type, RequestHistoryType.birthdayRequest);
      expect(success.items.single.status, RequestHistoryStatus.newRequest);
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
  Future<Result<void>> logout(MobileAuthSession session) async {
    return const Success<void>(null);
  }

  @override
  Future<Result<MobileAuthSession>> refreshSession(String refreshToken) async {
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
