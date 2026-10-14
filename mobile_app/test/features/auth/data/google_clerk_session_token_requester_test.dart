import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/features/auth/data/google_clerk_session_token_requester.dart';
import 'package:star_kids_mobile/features/auth/data/google_sign_in_gateway.dart';

void main() {
  testWidgets('missing configuration fails before native sign-in',
      (tester) async {
    final context = await pumpContext(tester);
    var authenticateCalls = 0;
    final requester = NativeGoogleClerkSessionTokenRequester(
      configurationOverride: false,
      googleGateway: _FakeGoogleGateway(
        onAuthenticate: () async {
          authenticateCalls++;
          return const GoogleIdentityToken(idToken: 'google-token');
        },
      ),
      operationsFactory: (_) => _FakeClerkOperations(),
    );

    await expectLater(
      requester.request(context),
      throwsA(isA<GoogleAuthConfigurationException>()),
    );
    expect(authenticateCalls, 0);
  });

  testWidgets('Google ID token is passed to Clerk and session JWT returned',
      (tester) async {
    final context = await pumpContext(tester);
    final operations = _FakeClerkOperations(isSignedIn: true);
    final requester = NativeGoogleClerkSessionTokenRequester(
      configurationOverride: true,
      googleGateway: _FakeGoogleGateway(
        onAuthenticate: () async =>
            const GoogleIdentityToken(idToken: 'google-id-token'),
      ),
      operationsFactory: (_) => operations,
    );

    final result = await requester.request(context);

    expect(result, 'clerk-session-jwt');
    expect(operations.resetCalls, 1);
    expect(operations.idToken, 'google-id-token');
  });

  testWidgets('missing Google ID token never reaches Clerk', (tester) async {
    final context = await pumpContext(tester);
    final operations = _FakeClerkOperations(isSignedIn: true);
    final requester = NativeGoogleClerkSessionTokenRequester(
      configurationOverride: true,
      googleGateway: _FakeGoogleGateway(
        onAuthenticate: () async => const GoogleIdentityToken(idToken: null),
      ),
      operationsFactory: (_) => operations,
    );

    await expectLater(
      requester.request(context),
      throwsA(isA<GoogleAuthTokenException>()),
    );
    expect(operations.idToken, isNull);
  });

  testWidgets('only supported missing name fields are completed',
      (tester) async {
    final context = await pumpContext(tester);
    final operations = _FakeClerkOperations(
      isSignedIn: true,
      missingFields: const [clerk.Field.firstName, clerk.Field.lastName],
    );
    final requester = NativeGoogleClerkSessionTokenRequester(
      configurationOverride: true,
      googleGateway: _FakeGoogleGateway(
        onAuthenticate: () async => const GoogleIdentityToken(
          idToken: 'google-id-token',
          displayName: 'Ada Lovelace',
        ),
      ),
      operationsFactory: (_) => operations,
    );

    await requester.request(context);

    expect(operations.completedFirstName, 'Ada');
    expect(operations.completedLastName, 'Lovelace');
  });

  testWidgets('legal or unknown required fields are never auto-accepted',
      (tester) async {
    final context = await pumpContext(tester);
    final operations = _FakeClerkOperations(
      isSignedIn: true,
      missingFields: const [clerk.Field.legalAccepted],
    );
    final requester = NativeGoogleClerkSessionTokenRequester(
      configurationOverride: true,
      googleGateway: _FakeGoogleGateway(
        onAuthenticate: () async => const GoogleIdentityToken(
          idToken: 'google-id-token',
          displayName: 'Ada Lovelace',
        ),
      ),
      operationsFactory: (_) => operations,
    );

    await expectLater(
      requester.request(context),
      throwsA(isA<GoogleAuthConfigurationException>()),
    );
    expect(operations.completeCalls, 0);
  });
}

Future<BuildContext> pumpContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        captured = context;
        return const SizedBox();
      },
    ),
  );
  return captured;
}

class _FakeGoogleGateway implements GoogleSignInGateway {
  _FakeGoogleGateway({required this.onAuthenticate});

  final Future<GoogleIdentityToken> Function() onAuthenticate;

  @override
  Future<GoogleIdentityToken> authenticate() => onAuthenticate();
}

class _FakeClerkOperations implements ClerkGoogleSignInOperations {
  _FakeClerkOperations({
    this.isSignedIn = false,
    this.missingFields = const <clerk.Field>[],
  });

  @override
  final bool isSignedIn;

  final List<clerk.Field> missingFields;

  int resetCalls = 0;
  int completeCalls = 0;
  String? idToken;
  String? completedFirstName;
  String? completedLastName;

  @override
  Future<void> resetClient() async => resetCalls++;

  @override
  Future<void> idTokenSignIn(String token) async => idToken = token;

  @override
  List<clerk.Field> get missingSignUpFields => missingFields;

  @override
  Future<void> completeSignUp({String? firstName, String? lastName}) async {
    completeCalls++;
    completedFirstName = firstName;
    completedLastName = lastName;
  }

  @override
  Future<String> sessionTokenJwt() async => 'clerk-session-jwt';
}
