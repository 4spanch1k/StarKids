import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../../../app/config/app_environment.dart';
import 'google_sign_in_gateway.dart';

abstract interface class ClerkGoogleSignInOperations {
  Future<void> resetClient();

  Future<void> idTokenSignIn(String token);

  List<clerk.Field> get missingSignUpFields;

  Future<void> completeSignUp({String? firstName, String? lastName});

  bool get isSignedIn;

  Future<String> sessionTokenJwt();
}

class ClerkAuthStateGoogleSignInOperations
    implements ClerkGoogleSignInOperations {
  ClerkAuthStateGoogleSignInOperations(this._authState);

  final ClerkAuthState _authState;

  @override
  Future<void> resetClient() => _authState.resetClient();

  @override
  Future<void> idTokenSignIn(String token) => _authState.idTokenSignIn(
        provider: clerk.IdTokenProvider.google,
        token: token,
      );

  @override
  List<clerk.Field> get missingSignUpFields =>
      _authState.signUp?.missingFields ?? const <clerk.Field>[];

  @override
  Future<void> completeSignUp({String? firstName, String? lastName}) =>
      _authState
          .attemptSignUp(
            strategy: clerk.IdTokenProvider.google.strategy,
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

abstract interface class GoogleClerkSessionTokenRequester {
  Future<String> request(BuildContext context);
}

class NativeGoogleClerkSessionTokenRequester
    implements GoogleClerkSessionTokenRequester {
  NativeGoogleClerkSessionTokenRequester({
    GoogleSignInGateway? googleGateway,
    ClerkGoogleSignInOperations Function(BuildContext)? operationsFactory,
    bool? configurationOverride,
  })  : _googleGateway = googleGateway ??
            NativeGoogleSignInGateway(
              serverClientId: AppEnvironment.googleServerClientId,
              clientId: AppEnvironment.googleIosClientId,
            ),
        _operationsFactory = operationsFactory ??
            ((context) => ClerkAuthStateGoogleSignInOperations(
                  ClerkAuth.of(context, listen: false),
                )),
        _isConfigured = configurationOverride ??
            (AppEnvironment.hasClerkPublishableKey &&
                AppEnvironment.hasGoogleSignInConfig);

  final GoogleSignInGateway _googleGateway;
  final ClerkGoogleSignInOperations Function(BuildContext) _operationsFactory;
  final bool _isConfigured;

  @override
  Future<String> request(BuildContext context) async {
    if (!_isConfigured) {
      throw const GoogleAuthConfigurationException();
    }

    final operations = _operationsFactory(context);
    await operations.resetClient();
    final identity = await _googleGateway.authenticate();
    final token = identity.idToken?.trim();
    if (token == null || token.isEmpty) {
      throw const GoogleAuthTokenException();
    }

    await operations.idTokenSignIn(token);
    final missingFields = operations.missingSignUpFields;
    if (missingFields.isNotEmpty) {
      final unsupportedFields = missingFields.where(
        (field) =>
            field != clerk.Field.firstName && field != clerk.Field.lastName,
      );
      if (unsupportedFields.isNotEmpty) {
        throw const GoogleAuthConfigurationException(
          'Clerk requires additional sign-up fields.',
        );
      }

      final name = _splitDisplayName(identity.displayName);
      final firstName =
          missingFields.contains(clerk.Field.firstName) ? name.first : null;
      final lastName =
          missingFields.contains(clerk.Field.lastName) ? name.last : null;
      if (missingFields.contains(clerk.Field.firstName) && firstName == null ||
          missingFields.contains(clerk.Field.lastName) && lastName == null) {
        throw const GoogleAuthConfigurationException(
          'Google profile does not provide required name fields.',
        );
      }
      await operations.completeSignUp(
        firstName: firstName,
        lastName: lastName,
      );
    }

    if (!operations.isSignedIn) {
      throw const GoogleAuthVerificationException();
    }
    final sessionToken = (await operations.sessionTokenJwt()).trim();
    if (sessionToken.isEmpty) {
      throw const GoogleAuthVerificationException();
    }
    return sessionToken;
  }

  static ({String? first, String? last}) _splitDisplayName(String? value) {
    final parts = value
            ?.trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList() ??
        const <String>[];
    if (parts.isEmpty) return (first: null, last: null);
    return (
      first: parts.first,
      last: parts.length > 1 ? parts.sublist(1).join(' ') : null,
    );
  }
}
