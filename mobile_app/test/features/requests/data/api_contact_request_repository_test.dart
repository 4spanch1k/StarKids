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
import 'package:star_kids_mobile/features/requests/data/api_contact_request_repository.dart';
import 'package:star_kids_mobile/features/requests/domain/contact_request_payload.dart';
import 'package:star_kids_mobile/features/requests/domain/contact_request_submission.dart';

void main() {
  group('ApiContactRequestRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('adds bearer token when a mobile auth session exists', () async {
      String? authorizationHeader;
      final sessionStorage = MobileAuthSessionStorage();
      final repository = ApiContactRequestRepository(
        apiClient: ApiClient(
          baseUrl: 'http://example.com',
          httpClient: MockClient((request) async {
            authorizationHeader = request.headers['Authorization'];
            return http.Response(
              jsonEncode({
                'id': 'contact-1',
                'type': 'contact',
                'status': 'new',
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

      final result = await repository.submitContactRequest(
        const ContactRequestPayload(
          name: 'Amina',
          phone: '+77071234567',
          message: 'Подскажите свободные даты.',
        ),
      );

      expect(result, isA<Success<ContactRequestSubmission>>());
      expect(authorizationHeader, 'Bearer access-token');
    });

    test('keeps anonymous submit behavior when no mobile auth session exists',
        () async {
      String? authorizationHeader;
      final sessionStorage = MobileAuthSessionStorage();
      final repository = ApiContactRequestRepository(
        apiClient: ApiClient(
          baseUrl: 'http://example.com',
          httpClient: MockClient((request) async {
            authorizationHeader = request.headers['Authorization'];
            return http.Response(
              jsonEncode({
                'id': 'contact-2',
                'type': 'contact',
                'status': 'new',
              }),
              201,
              headers: const {'content-type': 'application/json'},
            );
          }),
        ),
        sessionStorage: sessionStorage,
      );

      final result = await repository.submitContactRequest(
        const ContactRequestPayload(
          name: 'Dana',
          phone: '+77070000002',
        ),
      );

      expect(result, isA<Success<ContactRequestSubmission>>());
      expect(authorizationHeader, isNull);
    });
  });
}
