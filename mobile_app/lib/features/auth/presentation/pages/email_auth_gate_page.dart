import 'dart:async';

import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/config/app_environment.dart';
import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/sk_tokens.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/sk_fade.dart';
import '../../../../core/design_system/widgets/sk_field.dart';
import '../../../../core/design_system/widgets/sk_segment.dart';
import '../controllers/mobile_auth_controller.dart';

enum _EmailAuthMode {
  login,
  register,
}

class _GoogleClerkAuthException implements Exception {
  const _GoogleClerkAuthException([this.message]);

  final String? message;

  @override
  String toString() => message ?? 'Google auth failed.';
}

class EmailAuthGatePage extends StatefulWidget {
  const EmailAuthGatePage({super.key});

  @override
  State<EmailAuthGatePage> createState() => _EmailAuthGatePageState();
}

class _EmailAuthGatePageState extends State<EmailAuthGatePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final AnimationController _entryController;

  _EmailAuthMode _mode = _EmailAuthMode.login;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  MobileAuthController get _authController =>
      ServiceRegistry.mobileAuthController;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[CLERK] publishable key present='
      '${AppEnvironment.hasClerkPublishableKey}',
    );
    debugPrint('[CLERK] not initialized on startup');
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
      return;
    }

    if (_mode == _EmailAuthMode.register) {
      await _authController.registerWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      return;
    }

    await _authController.loginWithEmail(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  Future<void> _loginWithGoogleClerk(BuildContext clerkContext) async {
    await _authController.loginWithGoogleClerk(
      requestSessionToken: () => _requestGoogleClerkSessionToken(clerkContext),
    );
  }

  Future<String> _requestGoogleClerkSessionToken(
    BuildContext clerkContext,
  ) async {
    if (!AppEnvironment.hasClerkPublishableKey) {
      debugPrint('[CLERK] session token request blocked: missing key');
      throw const _GoogleClerkAuthException();
    }

    debugPrint('[CLERK] Google OAuth started');
    final authState = ClerkAuth.of(clerkContext, listen: false);
    clerk.ClerkError? signInError;

    await authState.ssoSignIn(
      clerkContext,
      clerk.Strategy.oauthGoogle,
      onError: (error) {
        signInError = error;
      },
    );

    if (signInError != null || !mounted) {
      debugPrint('[CLERK] Google OAuth failed: ${signInError?.message}');
      throw _GoogleClerkAuthException(signInError?.message);
    }

    final sessionToken = await authState.sessionToken();
    debugPrint('[CLERK] session token acquired');
    return sessionToken.jwt;
  }

  void _setMode(_EmailAuthMode mode) {
    if (_mode == mode) {
      return;
    }

    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _mode = mode;
      _confirmPasswordController.clear();
      _isConfirmPasswordVisible = false;
    });
    _authController.clearError();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        final c = SKTheme.of(context).colors;
        final isRegister = _mode == _EmailAuthMode.register;
        final isLoading = _authController.status == MobileAuthStatus.loading;
        final errorMessage = _authController.errorMessage;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: c.bg)),
              Positioned(
                top: -120,
                right: -90,
                child: Container(
                  width: 330,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.accent.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -90,
                bottom: -70,
                child: Container(
                  width: 260,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        SK.plum.withValues(alpha: 0.34),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final keyboardInset =
                        MediaQuery.viewInsetsOf(context).bottom;
                    final minContentHeight =
                        (constraints.maxHeight - keyboardInset)
                            .clamp(0.0, double.infinity)
                            .toDouble();

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        SK.s5,
                        SK.s5,
                        SK.s5,
                        SK.s5 + keyboardInset,
                      ),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: minContentHeight),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Form(
                              key: _formKey,
                              autovalidateMode: _autovalidateMode,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SkFade(
                                    delayMs: 40,
                                    child: _RedesignAuthHeader(),
                                  ),
                                  SizedBox(
                                    height: constraints.maxHeight < 700
                                        ? SK.s7
                                        : SK.s8 * 1.8,
                                  ),
                                  SkFade(
                                    delayMs: 120,
                                    child: _RedesignAuthIntro(
                                      isRegister: isRegister,
                                    ),
                                  ),
                                  const SizedBox(height: SK.s6),
                                  SkFade(
                                    delayMs: 200,
                                    child: SkSegment<_EmailAuthMode>(
                                      items: const [
                                        _EmailAuthMode.login,
                                        _EmailAuthMode.register,
                                      ],
                                      selected: _mode,
                                      labelBuilder: (mode) =>
                                          mode == _EmailAuthMode.login
                                              ? 'Вход'
                                              : 'Регистрация',
                                      onSelected: _setMode,
                                      enabled: !isLoading,
                                    ),
                                  ),
                                  const SizedBox(height: SK.s4),
                                  if (errorMessage != null) ...[
                                    _AuthErrorBanner(message: errorMessage),
                                    const SizedBox(height: SK.s4),
                                  ],
                                  SkFade(
                                    delayMs: 280,
                                    child: SkField(
                                      key: const ValueKey('auth-email-field'),
                                      controller: _emailController,
                                      label: 'Email',
                                      hintText: 'name@example.com',
                                      icon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      autocorrect: false,
                                      validator:
                                          _authController.validateEmailInput,
                                    ),
                                  ),
                                  const SizedBox(height: SK.s3),
                                  SkFade(
                                    delayMs: 360,
                                    child: SkField(
                                      key:
                                          const ValueKey('auth-password-field'),
                                      controller: _passwordController,
                                      label: 'Пароль',
                                      hintText: 'Минимум 8 символов',
                                      icon: Icons.lock_outline,
                                      obscureText: !_isPasswordVisible,
                                      autofillHints: [
                                        isRegister
                                            ? AutofillHints.newPassword
                                            : AutofillHints.password,
                                      ],
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textInputAction: isRegister
                                          ? TextInputAction.next
                                          : TextInputAction.done,
                                      validator:
                                          _authController.validatePasswordInput,
                                      trailing: IconButton(
                                        key: const ValueKey(
                                          'auth-password-visibility-toggle',
                                        ),
                                        onPressed: isLoading
                                            ? null
                                            : _togglePasswordVisibility,
                                        tooltip: _isPasswordVisible
                                            ? 'Скрыть пароль'
                                            : 'Показать пароль',
                                        icon: Icon(
                                          _isPasswordVisible
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: c.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 240),
                                    child: isRegister
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                              top: SK.s3,
                                            ),
                                            child: SkField(
                                              key: const ValueKey(
                                                'auth-confirm-password-field',
                                              ),
                                              controller:
                                                  _confirmPasswordController,
                                              label: 'Повтор пароля',
                                              hintText: 'Ещё раз пароль',
                                              icon: Icons.lock_outline,
                                              obscureText:
                                                  !_isConfirmPasswordVisible,
                                              autofillHints: const [
                                                AutofillHints.newPassword,
                                              ],
                                              autocorrect: false,
                                              enableSuggestions: false,
                                              textInputAction:
                                                  TextInputAction.done,
                                              validator: (value) => _authController
                                                  .validatePasswordConfirmation(
                                                password:
                                                    _passwordController.text,
                                                confirmation: value,
                                              ),
                                              trailing: IconButton(
                                                key: const ValueKey(
                                                  'auth-confirm-password-visibility-toggle',
                                                ),
                                                onPressed: isLoading
                                                    ? null
                                                    : _toggleConfirmPasswordVisibility,
                                                tooltip:
                                                    _isConfirmPasswordVisible
                                                        ? 'Скрыть пароль'
                                                        : 'Показать пароль',
                                                icon: Icon(
                                                  _isConfirmPasswordVisible
                                                      ? Icons
                                                          .visibility_off_outlined
                                                      : Icons
                                                          .visibility_outlined,
                                                  color: c.textTertiary,
                                                ),
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  const SizedBox(height: SK.s5),
                                  SkFade(
                                    delayMs: 440,
                                    child: PrimaryButton(
                                      label: isRegister
                                          ? 'Создать аккаунт'
                                          : 'Войти',
                                      icon: Icons.arrow_forward_rounded,
                                      onPressed: isLoading
                                          ? null
                                          : () async {
                                              await Future<void>.delayed(
                                                const Duration(
                                                    milliseconds: 250),
                                              );
                                              await _submit();
                                            },
                                    ),
                                  ),
                                  const SizedBox(height: SK.s4),
                                  const _AuthDivider(),
                                  const SizedBox(height: SK.s4),
                                  SkFade(
                                    delayMs: 500,
                                    child: _GoogleClerkAuthButton(
                                      isConfigured:
                                          AppEnvironment.hasClerkPublishableKey,
                                      isLoading: isLoading,
                                      onPressed: _loginWithGoogleClerk,
                                    ),
                                  ),
                                  const SizedBox(height: SK.s5),
                                  const _RedesignSessionHint(),
                                  const SizedBox(height: SK.s8),
                                  Text(
                                    'Продолжая, вы соглашаетесь с правилами Star Kids.',
                                    textAlign: TextAlign.center,
                                    style: SKTextStyles.small.copyWith(
                                      fontSize: 11,
                                      height: 1.35,
                                      color: c.textDisabled,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RedesignAuthHeader extends StatelessWidget {
  const _RedesignAuthHeader();

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: c.textPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '★',
              style: TextStyle(
                fontFamily: SKTypography.display,
                fontSize: 18,
                color: c.bg,
              ),
            ),
          ),
        ),
        const SizedBox(width: SK.s3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Star Kids',
              style: SKTextStyles.h3.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Almaty · Al-Farabi',
              style: SKTextStyles.small.copyWith(
                fontSize: 12,
                color: c.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RedesignAuthIntro extends StatelessWidget {
  const _RedesignAuthIntro({required this.isRegister});

  final bool isRegister;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Column(
        key: ValueKey(isRegister),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'Привет, '),
                TextSpan(
                  text: 'родители',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                TextSpan(text: '.\nПраздник в один тап.'),
              ],
            ),
            style: SKTextStyles.d1.copyWith(
              fontSize: 44,
              height: 1,
              letterSpacing: -1.32,
              fontWeight: FontWeight.w400,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: SK.s4),
          SizedBox(
            width: 260,
            child: Text(
              isRegister
                  ? 'Создайте аккаунт, чтобы заявки и профиль были под рукой.'
                  : 'Войдите, чтобы открыть заявки, профиль и любимый филиал.',
              style: SKTextStyles.body.copyWith(
                height: 1.45,
                color: c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RedesignSessionHint extends StatelessWidget {
  const _RedesignSessionHint();

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 12, color: c.textTertiary),
        const SizedBox(width: SK.s2),
        Flexible(
          child: Text(
            'Сессия сохраняется на этом устройстве',
            textAlign: TextAlign.center,
            style: SKTextStyles.small.copyWith(
              fontSize: 12,
              color: c.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Row(
      children: [
        Expanded(child: Divider(color: c.hairline, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SK.s3),
          child: Text(
            'или',
            style: SKTextStyles.small.copyWith(
              fontSize: 12,
              color: c.textTertiary,
            ),
          ),
        ),
        Expanded(child: Divider(color: c.hairline, height: 1)),
      ],
    );
  }
}

class _GoogleAuthButton extends StatelessWidget {
  const _GoogleAuthButton({
    required this.isConfigured,
    required this.isLoading,
    required this.onPressed,
    this.statusMessage,
  });

  final bool isConfigured;
  final bool isLoading;
  final VoidCallback onPressed;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final isEnabled = isConfigured && !isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecondaryButton(
          label: 'Продолжить с Google',
          icon: Icons.g_mobiledata_rounded,
          fullWidth: true,
          onPressed: isEnabled ? onPressed : null,
        ),
        if (!isConfigured || statusMessage != null) ...[
          const SizedBox(height: SK.s2),
          Text(
            statusMessage ??
                'Google вход недоступен: не задан Clerk publishable key.',
            textAlign: TextAlign.center,
            style: SKTextStyles.small.copyWith(
              fontSize: 11,
              height: 1.35,
              color: c.textDisabled,
            ),
          ),
        ],
      ],
    );
  }
}

class _GoogleClerkAuthButton extends StatefulWidget {
  const _GoogleClerkAuthButton({
    required this.isConfigured,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isConfigured;
  final bool isLoading;
  final Future<void> Function(BuildContext clerkContext) onPressed;

  @override
  State<_GoogleClerkAuthButton> createState() => _GoogleClerkAuthButtonState();
}

class _GoogleClerkAuthButtonState extends State<_GoogleClerkAuthButton> {
  static const _clerkInitializationTimeout = Duration(seconds: 15);

  bool _isClerkRequested = false;
  bool _didLauncherStart = false;
  bool _hasInitializationError = false;
  Timer? _initializationTimer;

  @override
  void didUpdateWidget(covariant _GoogleClerkAuthButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isConfigured && oldWidget.isConfigured) {
      _resetClerkRequest();
    }
  }

  @override
  void dispose() {
    _initializationTimer?.cancel();
    super.dispose();
  }

  void _requestClerkSignIn() {
    debugPrint('[CLERK] initialization requested by Google button');
    setState(() {
      _isClerkRequested = true;
      _didLauncherStart = false;
      _hasInitializationError = false;
    });

    _initializationTimer?.cancel();
    _initializationTimer = Timer(_clerkInitializationTimeout, () {
      if (!mounted || _didLauncherStart) {
        return;
      }

      setState(() {
        _isClerkRequested = false;
        _hasInitializationError = true;
      });
    });
  }

  void _resetClerkRequest() {
    _initializationTimer?.cancel();
    _isClerkRequested = false;
    _didLauncherStart = false;
  }

  void _markLauncherStarted() {
    _initializationTimer?.cancel();
    _didLauncherStart = true;
  }

  Future<void> _runClerkSignIn(BuildContext clerkContext) async {
    try {
      await widget.onPressed(clerkContext);
    } finally {
      if (mounted) {
        setState(_resetClerkRequest);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isConfigured) {
      return _GoogleAuthButton(
        isConfigured: false,
        isLoading: widget.isLoading,
        onPressed: () {},
      );
    }

    if (_hasInitializationError) {
      return _GoogleAuthButton(
        isConfigured: false,
        isLoading: false,
        onPressed: () {},
        statusMessage:
            'Google вход временно недоступен. Проверьте Clerk publishable key.',
      );
    }

    if (!_isClerkRequested) {
      return _GoogleAuthButton(
        isConfigured: true,
        isLoading: widget.isLoading,
        onPressed: _requestClerkSignIn,
      );
    }

    return ClerkAuth(
      config: ClerkAuthConfig(
        publishableKey: AppEnvironment.clerkPublishableKey,
        loading: _GoogleAuthButton(
          isConfigured: true,
          isLoading: true,
          onPressed: () {},
          statusMessage: 'Готовим вход через Google...',
        ),
      ),
      child: Builder(
        builder: (clerkContext) {
          return _GoogleClerkSignInLauncher(
            onStarted: _markLauncherStarted,
            onStart: () => _runClerkSignIn(clerkContext),
          );
        },
      ),
    );
  }
}

class _GoogleClerkSignInLauncher extends StatefulWidget {
  const _GoogleClerkSignInLauncher({
    required this.onStarted,
    required this.onStart,
  });

  final VoidCallback onStarted;
  final Future<void> Function() onStart;

  @override
  State<_GoogleClerkSignInLauncher> createState() =>
      _GoogleClerkSignInLauncherState();
}

class _GoogleClerkSignInLauncherState
    extends State<_GoogleClerkSignInLauncher> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started) {
        return;
      }

      _started = true;
      widget.onStarted();
      unawaited(widget.onStart());
    });
  }

  @override
  Widget build(BuildContext context) {
    return _GoogleAuthButton(
      isConfigured: true,
      isLoading: true,
      onPressed: () {},
      statusMessage: 'Открываем вход через Google...',
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.all(SKSpacing.x4),
      decoration: BoxDecoration(
        color: c.dangerSoft,
        borderRadius: BorderRadius.circular(SKRadius.lg),
        border: Border.all(color: c.danger.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(SKRadius.pill),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: c.danger,
            ),
          ),
          const SizedBox(width: SKSpacing.x4),
          Expanded(
            child: Text(
              message,
              style: SKTextStyles.body.copyWith(
                color: c.danger,
                height: 1.34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
