import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/core/api/api_client.dart';
import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/auth/data/mobile_auth_session_storage.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_session.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_user.dart';
import 'package:star_kids_mobile/features/requests/data/api_birthday_request_repository.dart';
import 'package:star_kids_mobile/features/requests/domain/birthday_request_payload.dart';
import 'package:star_kids_mobile/features/requests/domain/birthday_request_submission.dart';

void main() {
  group('ApiBirthdayRequestRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('adds bearer token when a mobile auth session exists', () async {
      String? authorizationHeader;
      final sessionStorage = MobileAuthSessionStorage();
      final repository = ApiBirthdayRequestRepository(
        apiClient: ApiClient(
          baseUrl: 'http://example.com',
          httpClient: MockClient((request) async {
            authorizationHeader = request.headers['Authorization'];
            return http.Response(
              jsonEncode({
                'requestId': 'request-1',
                'submittedAt': '2026-04-09T01:00:00Z',
                'nextStep': 'Менеджер свяжется с вами для подтверждения деталей',
              }),
              201,
              headers: const {'content-type': 'application/json'},
            );
          }),
        ),
        sessionStorage: sessionStorage,
      );

      await sessionStorage.saveSession(
        MobileAuthSession(
          user: const MobileAuthUser(id: 'user-1', phone: '+77071234567'),
          phone: '+77071234567',
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          tokenType: 'bearer',
          verifiedAt: DateTime.parse('2026-04-09T01:00:00Z'),
        ),
      );

      final result = await repository.submitBirthdayRequest(
        BirthdayRequestPayload(
          name: 'Amina',
          phone: '+77071234567',
          branchId: 'branch-main',
          preferredDate: DateTime(2026, 4, 10),
          guestCount: 10,
        ),
      );

      expect(result, isA<Success<BirthdayRequestSubmission>>());
      expect(authorizationHeader, 'Bearer access-token');
    });

    test('keeps anonymous submit behavior when no mobile auth session exists', () async {
      String? authorizationHeader;
      final sessionStorage = MobileAuthSessionStorage();
      final repository = ApiBirthdayRequestRepository(
        apiClient: ApiClient(
          baseUrl: 'http://example.com',
          httpClient: MockClient((request) async {
            authorizationHeader = request.headers['Authorization'];
            return http.Response(
              jsonEncode({
                'requestId': 'request-2',
                'submittedAt': '2026-04-09T01:00:00Z',
                'nextStep': 'Менеджер свяжется с вами для подтверждения деталей',
              }),
              201,
              headers: const {'content-type': 'application/json'},
            );
          }),
        ),
        sessionStorage: sessionStorage,
      );

      final result = await repository.submitBirthdayRequest(
        BirthdayRequestPayload(
          name: 'Dana',
          phone: '+77070000002',
          branchId: 'branch-main',
          preferredDate: DateTime(2026, 4, 10),
          guestCount: 8,
        ),
      );

      expect(result, isA<Success<BirthdayRequestSubmission>>());
      expect(authorizationHeader, isNull);
    });
  });
}
