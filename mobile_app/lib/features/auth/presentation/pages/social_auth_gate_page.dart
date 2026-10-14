import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../app/config/app_environment.dart';
import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/sk_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../data/apple_clerk_session_token_requester.dart';
import '../../data/google_clerk_session_token_requester.dart';
import '../../data/google_sign_in_gateway.dart';
import '../controllers/mobile_auth_controller.dart';

class SocialAuthGatePage extends StatefulWidget {
  const SocialAuthGatePage({super.key});

  @override
  State<SocialAuthGatePage> createState() => _SocialAuthGatePageState();
}

class _SocialAuthGatePageState extends State<SocialAuthGatePage> {
  final _googleRequester = NativeGoogleClerkSessionTokenRequester();
  final _appleRequester = NativeAppleClerkSessionTokenRequester();

  MobileAuthController get _auth => ServiceRegistry.mobileAuthController;

  Future<void> _signInWithGoogle() async {
    await _auth.loginWithClerk(
      providerName: 'Google',
      requestSessionToken: () async {
        try {
          return await _googleRequester.request(context);
        } on GoogleAuthCancelledException {
          throw const MobileAuthCancelledException();
        }
      },
    );
  }

  Future<void> _signInWithApple() async {
    await _auth.loginWithClerk(
      providerName: 'Apple',
      requestSessionToken: () async {
        try {
          return await _appleRequester.request(context);
        } on SignInWithAppleAuthorizationException catch (error) {
          if (error.code == AuthorizationErrorCode.canceled) {
            throw const MobileAuthCancelledException();
          }
          rethrow;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _auth,
      builder: (context, _) {
        final colors = SKTheme.of(context).colors;
        final loading = _auth.isBusy;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(SK.s5),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Boom Bala',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: SK.s3),
                      Text(
                        'Войдите, чтобы открыть семейный аккаунт и билеты.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: SK.s8),
                      PrimaryButton(
                        label: 'Продолжить с Google',
                        onPressed: loading ? null : _signInWithGoogle,
                        icon: Icons.account_circle_outlined,
                      ),
                      if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                        const SizedBox(height: SK.s3),
                        OutlinedButton.icon(
                          onPressed: loading ? null : _signInWithApple,
                          icon: const Icon(Icons.apple),
                          label: const Text('Войти с Apple'),
                        ),
                      ],
                      if (_auth.errorMessage != null) ...[
                        const SizedBox(height: SK.s4),
                        Text(
                          _auth.errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.danger),
                        ),
                      ],
                      if (!AppEnvironment.hasClerkPublishableKey) ...[
                        const SizedBox(height: SK.s4),
                        Text(
                          'Социальный вход пока не настроен для этого окружения.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
