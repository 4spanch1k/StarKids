import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

class GoogleIdentityToken {
  const GoogleIdentityToken({required this.idToken, this.displayName});

  final String? idToken;
  final String? displayName;
}

abstract interface class GoogleSignInGateway {
  Future<GoogleIdentityToken> authenticate();
}

class GoogleAuthCancelledException implements Exception {
  const GoogleAuthCancelledException();
}

class GoogleAuthConfigurationException implements Exception {
  const GoogleAuthConfigurationException([this.message]);

  final String? message;
}

class GoogleAuthTokenException implements Exception {
  const GoogleAuthTokenException();
}

class GoogleAuthVerificationException implements Exception {
  const GoogleAuthVerificationException();
}

class NativeGoogleSignInGateway implements GoogleSignInGateway {
  NativeGoogleSignInGateway({
    required this.serverClientId,
    this.clientId,
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final String serverClientId;
  final String? clientId;
  final GoogleSignIn _googleSignIn;

  static Future<void>? _initialization;
  static String? _initializedServerClientId;

  Future<void> _ensureInitialized() {
    final normalizedServerClientId = serverClientId.trim();
    if (normalizedServerClientId.isEmpty) {
      throw const GoogleAuthConfigurationException(
        'MOBILE_GOOGLE_SERVER_CLIENT_ID is missing.',
      );
    }

    final initializedClientId = _initializedServerClientId;
    if (initializedClientId != null &&
        initializedClientId != normalizedServerClientId) {
      throw const GoogleAuthConfigurationException(
        'Google Sign-In was initialized with a different server client ID.',
      );
    }
    _initializedServerClientId ??= normalizedServerClientId;
    return _initialization ??= _googleSignIn.initialize(
      serverClientId: normalizedServerClientId,
      nonce: const Uuid().v4(),
      clientId: switch (clientId?.trim()) {
        final value when value != null && value.isNotEmpty => value,
        _ => null,
      },
    );
  }

  @override
  Future<GoogleIdentityToken> authenticate() async {
    try {
      await _ensureInitialized();
      final account = await _googleSignIn.authenticate(
        scopeHint: const ['openid', 'email', 'profile'],
      );
      return GoogleIdentityToken(
        idToken: account.authentication.idToken,
        displayName: account.displayName,
      );
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          throw const GoogleAuthCancelledException();
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw GoogleAuthConfigurationException(error.description);
        default:
          rethrow;
      }
    }
  }
}
