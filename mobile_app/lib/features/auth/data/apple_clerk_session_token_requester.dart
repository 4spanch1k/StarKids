import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/config/app_environment.dart';

abstract interface class ClerkAppleSignInOperations {
  Future<void> resetClient();
  Future<void> idTokenSignIn(String token);
  List<clerk.Field> get missingSignUpFields;
  Future<void> completeSignUp({String? firstName, String? lastName});
  bool get isSignedIn;
  Future<String> sessionTokenJwt();
}

class ClerkAuthStateAppleSignInOperations
    implements ClerkAppleSignInOperations {
  ClerkAuthStateAppleSignInOperations(this._authState);

  final ClerkAuthState _authState;

  @override
  Future<void> resetClient() => _authState.resetClient();

  @override
  Future<void> idTokenSignIn(String token) => _authState.idTokenSignIn(
        provider: clerk.IdTokenProvider.apple,
        token: token,
      );

  @override
  List<clerk.Field> get missingSignUpFields =>
      _authState.signUp?.missingFields ?? const <clerk.Field>[];

  @override
  Future<void> completeSignUp({String? firstName, String? lastName}) =>
      _authState
          .attemptSignUp(
            strategy: clerk.IdTokenProvider.apple.strategy,
            firstName: firstName,
            lastName: lastName,
          )
          .then((_) {});

  @override
  bool get isSignedIn => _authState.isSignedIn;

  @override
  Future<String> sessionTokenJwt() async =>
      (await _authState.sessionToken()).jwt;
}

class AppleAuthConfigurationException implements Exception {
  const AppleAuthConfigurationException([
    this.message = 'Apple authentication is not configured.',
  ]);

  final String message;
}

class AppleAuthTokenException implements Exception {
  const AppleAuthTokenException();
}

class AppleAuthVerificationException implements Exception {
  const AppleAuthVerificationException();
}

class NativeAppleClerkSessionTokenRequester {
  NativeAppleClerkSessionTokenRequester({
    ClerkAppleSignInOperations Function(BuildContext)? operationsFactory,
    bool? configurationOverride,
  })  : _operationsFactory = operationsFactory ??
            ((context) => ClerkAuthStateAppleSignInOperations(
                  ClerkAuth.of(context, listen: false),
                )),
        _isConfigured =
            configurationOverride ?? AppEnvironment.hasClerkPublishableKey;

  final ClerkAppleSignInOperations Function(BuildContext) _operationsFactory;
  final bool _isConfigured;

  Future<String> request(BuildContext context) async {
    if (!_isConfigured || defaultTargetPlatform != TargetPlatform.iOS) {
      throw const AppleAuthConfigurationException();
    }

    final operations = _operationsFactory(context);
    await operations.resetClient();
    final credential = await SignInWithApple.getAppleIDCredential(
      nonce: const Uuid().v4(),
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final token = credential.identityToken?.trim();
    if (token == null || token.isEmpty) {
      throw const AppleAuthTokenException();
    }

    await operations.idTokenSignIn(token);
    final missingFields = operations.missingSignUpFields;
    if (missingFields.isNotEmpty) {
      final unsupportedFields = missingFields.where(
        (field) =>
            field != clerk.Field.firstName && field != clerk.Field.lastName,
      );
      if (unsupportedFields.isNotEmpty) {
        throw const AppleAuthConfigurationException(
          'Clerk requires additional sign-up fields.',
        );
      }
      if (missingFields.contains(clerk.Field.firstName) &&
          (credential.givenName?.trim().isEmpty ?? true)) {
        throw const AppleAuthConfigurationException(
          'Apple profile does not provide a required first name.',
        );
      }
      await operations.completeSignUp(
        firstName: missingFields.contains(clerk.Field.firstName)
            ? credential.givenName?.trim()
            : null,
        lastName: missingFields.contains(clerk.Field.lastName)
            ? credential.familyName?.trim()
            : null,
      );
    }

    if (!operations.isSignedIn) {
      throw const AppleAuthVerificationException();
    }
    final sessionToken = (await operations.sessionTokenJwt()).trim();
    if (sessionToken.isEmpty) {
      throw const AppleAuthVerificationException();
    }
    return sessionToken;
  }
}
