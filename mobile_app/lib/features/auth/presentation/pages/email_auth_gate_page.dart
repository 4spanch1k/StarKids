// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_icon_sizes.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/foundations/sk_tokens.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/sk_fade.dart';
import '../../../../core/design_system/widgets/sk_field.dart';
import '../../../../core/design_system/widgets/sk_segment.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../controllers/mobile_auth_controller.dart';

enum _EmailAuthMode {
  login,
  register,
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

  Animation<double> _entryInterval(double begin, double end) {
    return CurvedAnimation(
      parent: _entryController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
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
                                      controller: _emailController,
                                      label: 'Email',
                                      hintText: 'name@example.com',
                                      icon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator:
                                          _authController.validateEmailInput,
                                    ),
                                  ),
                                  const SizedBox(height: SK.s3),
                                  SkFade(
                                    delayMs: 360,
                                    child: SkField(
                                      controller: _passwordController,
                                      label: 'Пароль',
                                      hintText: 'Минимум 8 символов',
                                      icon: Icons.lock_outline,
                                      obscureText: !_isPasswordVisible,
                                      textInputAction: isRegister
                                          ? TextInputAction.next
                                          : TextInputAction.done,
                                      validator:
                                          _authController.validatePasswordInput,
                                      trailing: IconButton(
                                        onPressed: isLoading
                                            ? null
                                            : _togglePasswordVisibility,
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
                                              controller:
                                                  _confirmPasswordController,
                                              label: 'Повтор пароля',
                                              hintText: 'Ещё раз пароль',
                                              icon: Icons.lock_outline,
                                              obscureText:
                                                  !_isConfirmPasswordVisible,
                                              textInputAction:
                                                  TextInputAction.done,
                                              validator: (value) => _authController
                                                  .validatePasswordConfirmation(
                                                password:
                                                    _passwordController.text,
                                                confirmation: value,
                                              ),
                                              trailing: IconButton(
                                                onPressed: isLoading
                                                    ? null
                                                    : _toggleConfirmPasswordVisibility,
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

class _RevealMotion extends StatelessWidget {
  const _RevealMotion({
    required this.animation,
    required this.child,
    this.offset = const Offset(0, 0.08),
  });

  final Animation<double> animation;
  final Widget child;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: offset,
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

/// Warm SK logo with a dark near-black background and gold star.
/// Uses TweenAnimationBuilder (one-shot, terminates) so pumpAndSettle works in tests.
class _CosmicSkLogo extends StatelessWidget {
  const _CosmicSkLogo();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF2B1F1A),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2B1F1A).withValues(alpha: 0.18 * t),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '★',
              style: TextStyle(
                color: Color(0xFFFFC857),
                fontSize: 30,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AuthBrandIntro extends StatelessWidget {
  const _AuthBrandIntro({
    required this.isRegister,
  });

  final bool isRegister;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Column(
        key: ValueKey(isRegister),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _CosmicSkLogo(),
          const SizedBox(height: StarKidsSpacing.lg),
          Text(
            'Star Kids',
            style: textTheme.labelLarge?.copyWith(
              color: StarKidsColors.brandAccent,
              letterSpacing: 0.8,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: StarKidsSpacing.sm),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Привет, '),
                TextSpan(
                  text: 'родители',
                  style: TextStyle(
                    fontFamily: 'Fraunces',
                    fontStyle: FontStyle.italic,
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    color: StarKidsColors.brandAccent,
                  ),
                ),
                TextSpan(text: '.\nПраздник в один тап.'),
              ],
            ),
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 22,
              fontWeight: FontWeight.w400,
              height: 1.18,
              color: StarKidsColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(
            isRegister
                ? 'Создайте аккаунт, чтобы заявки и профиль оставались под рукой.'
                : 'Войдите, чтобы продолжить к заявкам, профилю и избранному филиалу.',
            style: textTheme.bodyLarge?.copyWith(
              height: 1.38,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: StarKidsSpacing.md),
          const _AuthTrustChip(),
        ],
      ),
    );
  }
}

class _AuthTrustChip extends StatelessWidget {
  const _AuthTrustChip();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 920),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final entryGlow = 1 - value;

        final isTrustDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: StarKidsSpacing.md,
            vertical: StarKidsSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isTrustDark
                ? StarKidsDarkColors.glassSurface
                : StarKidsColors.glassSurface,
            borderRadius: BorderRadius.circular(StarKidsRadii.full),
            border: Border.all(
              color: Color.lerp(
                isTrustDark
                    ? StarKidsDarkColors.borderDefault
                    : StarKidsColors.borderDefault,
                isTrustDark
                    ? StarKidsDarkColors.glassStroke
                    : StarKidsColors.glassStroke,
                value,
              )!,
            ),
            boxShadow: [
              BoxShadow(
                color: StarKidsColors.brandSecondary.withValues(
                  alpha: 0.04 + entryGlow * 0.08,
                ),
                blurRadius: 12 + entryGlow * 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Opacity(
            opacity: 0.72 + value * 0.28,
            child: Transform.translate(
              offset: Offset(0, 6 * entryGlow),
              child: child,
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_rounded,
            size: StarKidsIconSizes.sm,
            color: StarKidsColors.brandSecondary,
          ),
          const SizedBox(width: StarKidsSpacing.sm),
          Flexible(
            child: Text(
              'Сессия сохраняется на этом устройстве',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthFormCard extends StatelessWidget {
  const _AuthFormCard({
    required this.formKey,
    required this.autovalidateMode,
    required this.mode,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.errorMessage,
    required this.isPasswordVisible,
    required this.isConfirmPasswordVisible,
    required this.onModeChanged,
    required this.onSubmit,
    required this.onPasswordVisibilityChanged,
    required this.onConfirmPasswordVisibilityChanged,
    required this.emailValidator,
    required this.passwordValidator,
    required this.confirmationValidator,
  });

  final GlobalKey<FormState> formKey;
  final AutovalidateMode autovalidateMode;
  final _EmailAuthMode mode;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final String? errorMessage;
  final bool isPasswordVisible;
  final bool isConfirmPasswordVisible;
  final ValueChanged<_EmailAuthMode> onModeChanged;
  final Future<void> Function() onSubmit;
  final VoidCallback onPasswordVisibilityChanged;
  final VoidCallback onConfirmPasswordVisibilityChanged;
  final String? Function(String?) emailValidator;
  final String? Function(String?) passwordValidator;
  final String? Function(String?) confirmationValidator;

  bool get _isRegister => mode == _EmailAuthMode.register;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.06),
              ]
            : const [
                Color(0xF0FFFFFF),
                Color(0xD8FFFFFF),
              ],
      ),
      borderRadius: BorderRadius.circular(StarKidsRadii.hero),
      border: Border.all(
        color: isDark
            ? StarKidsDarkColors.glassStroke
            : StarKidsColors.glassStroke,
      ),
      boxShadow: isDark ? const [] : StarKidsShadows.cosmicCard,
    );

    final cardContent = AnimatedSize(
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: Form(
        key: formKey,
        autovalidateMode: autovalidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: _slideFadeTransition,
              child: Column(
                key: ValueKey('copy-${mode.name}'),
                children: [
                  Text(
                    _isRegister ? 'Создать аккаунт' : 'С возвращением',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: StarKidsSpacing.xs),
                  Text(
                    _isRegister
                        ? 'Заполните почту и пароль. Это займет меньше минуты.'
                        : 'Введите почту и пароль, чтобы открыть приложение.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.36,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            _AuthModeSwitch(
              mode: mode,
              onChanged: isLoading ? null : onModeChanged,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: _slideFadeTransition,
              child: errorMessage == null
                  ? const SizedBox.shrink()
                  : Padding(
                      key: ValueKey(errorMessage),
                      padding: const EdgeInsets.only(top: StarKidsSpacing.lg),
                      child: _AuthErrorBanner(message: errorMessage!),
                    ),
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            AutofillGroup(
              child: Column(
                children: [
                  _AuthTextField(
                    controller: emailController,
                    label: 'Электронная почта',
                    hintText: 'name@example.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icons.email_rounded,
                    enabled: !isLoading,
                    validator: emailValidator,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: StarKidsSpacing.md),
                  _AuthTextField(
                    controller: passwordController,
                    label: 'Пароль',
                    hintText: 'Минимум 8 символов',
                    textInputAction: _isRegister
                        ? TextInputAction.next
                        : TextInputAction.done,
                    prefixIcon: Icons.lock_rounded,
                    enabled: !isLoading,
                    obscureText: !isPasswordVisible,
                    validator: passwordValidator,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) {
                      if (!_isRegister && !isLoading) {
                        onSubmit();
                      }
                    },
                    suffix: _PasswordVisibilityButton(
                      isVisible: isPasswordVisible,
                      onPressed: isLoading ? null : onPasswordVisibilityChanged,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: _slideFadeTransition,
                    child: _isRegister
                        ? Padding(
                            key: const ValueKey('confirm-password'),
                            padding: const EdgeInsets.only(
                              top: StarKidsSpacing.md,
                            ),
                            child: _AuthTextField(
                              controller: confirmPasswordController,
                              label: 'Подтверждение пароля',
                              hintText: 'Повторите пароль',
                              textInputAction: TextInputAction.done,
                              prefixIcon: Icons.verified_user_rounded,
                              enabled: !isLoading,
                              obscureText: !isConfirmPasswordVisible,
                              validator: confirmationValidator,
                              autofillHints: const [AutofillHints.newPassword],
                              onFieldSubmitted: (_) {
                                if (!isLoading) {
                                  onSubmit();
                                }
                              },
                              suffix: _PasswordVisibilityButton(
                                isVisible: isConfirmPasswordVisible,
                                onPressed: isLoading
                                    ? null
                                    : onConfirmPasswordVisibilityChanged,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: StarKidsSpacing.xl),
            AnimatedScale(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              scale: isLoading ? 0.98 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(minHeight: 56),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(StarKidsRadii.full),
                  boxShadow: isLoading ? const [] : StarKidsShadows.brandGlow,
                ),
                child: StarKidsButton.primary(
                  label: _isRegister ? 'Зарегистрироваться' : 'Войти',
                  onPressed: isLoading ? null : () => onSubmit(),
                  isLoading: isLoading,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isDark) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(StarKidsRadii.hero),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(StarKidsSpacing.xl),
            decoration: cardDecoration,
            child: cardContent,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      decoration: cardDecoration,
      child: cardContent,
    );
  }
}

Widget _slideFadeTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}

class _AuthTextField extends StatefulWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.enabled = true,
    this.obscureText = false,
    this.validator,
    this.autofillHints,
    this.onFieldSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final bool enabled;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffix;

  @override
  State<_AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<_AuthTextField> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_isFocused == _focusNode.hasFocus) {
      return;
    }

    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: _isFocused ? 1.012 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(StarKidsRadii.md),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: StarKidsColors.brandPrimary.withValues(alpha: 0.14),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : const [],
        ),
        child: TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          enabled: widget.enabled,
          obscureText: widget.obscureText,
          enableSuggestions: !widget.obscureText,
          autocorrect: !widget.obscureText,
          validator: widget.validator,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onFieldSubmitted,
          cursorColor: StarKidsColors.brandPrimary,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText,
            prefixIcon:
                widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
            suffixIcon: widget.suffix,
          ),
        ),
      ),
    );
  }
}

class _PasswordVisibilityButton extends StatelessWidget {
  const _PasswordVisibilityButton({
    required this.isVisible,
    required this.onPressed,
  });

  final bool isVisible;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: isVisible ? 'Скрыть пароль' : 'Показать пароль',
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Icon(
          isVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          key: ValueKey(isVisible),
        ),
      ),
    );
  }
}

class _AuthHintText extends StatelessWidget {
  const _AuthHintText({
    required this.isRegister,
  });

  final bool isRegister;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: _slideFadeTransition,
      child: Text(
        isRegister
            ? 'После регистрации вход сохранится на этом устройстве.'
            : 'Если аккаунта еще нет, переключитесь на регистрацию.',
        key: ValueKey(isRegister),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              height: 1.35,
            ),
      ),
    );
  }
}

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({
    required this.mode,
    required this.onChanged,
  });

  final _EmailAuthMode mode;
  final ValueChanged<_EmailAuthMode>? onChanged;

  bool get _isLogin => mode == _EmailAuthMode.login;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final selectedStyle = textTheme.labelLarge?.copyWith(
      color:
          isDark ? StarKidsDarkColors.textPrimary : StarKidsColors.textPrimary,
      fontWeight: FontWeight.w800,
    );
    final idleStyle = textTheme.labelLarge?.copyWith(
      color: isDark
          ? StarKidsDarkColors.textSecondary
          : StarKidsColors.textSecondary,
      fontWeight: FontWeight.w700,
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: isEnabled ? 1 : 0.62,
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(StarKidsSpacing.xs),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0x24E5D4F2), Color(0x18C7DDEF)],
                )
              : const LinearGradient(
                  colors: [StarKidsColors.warmCoral, StarKidsColors.warmPlum],
                ),
          borderRadius: BorderRadius.circular(StarKidsRadii.full),
          border: Border.all(
            color: isDark
                ? StarKidsDarkColors.borderDefault
                : StarKidsColors.glassStroke,
          ),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment:
                  _isLogin ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? StarKidsDarkColors.glassSurface
                        : StarKidsColors.glassSurface,
                    borderRadius: BorderRadius.circular(StarKidsRadii.full),
                    boxShadow: [
                      BoxShadow(
                        color:
                            StarKidsColors.brandPrimary.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _AuthModeHitArea(
                  label: 'Вход',
                  isSelected: _isLogin,
                  isEnabled: isEnabled,
                  style: _isLogin ? selectedStyle : idleStyle,
                  onTap: () => onChanged?.call(_EmailAuthMode.login),
                ),
                _AuthModeHitArea(
                  label: 'Регистрация',
                  isSelected: !_isLogin,
                  isEnabled: isEnabled,
                  style: !_isLogin ? selectedStyle : idleStyle,
                  onTap: () => onChanged?.call(_EmailAuthMode.register),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthModeHitArea extends StatelessWidget {
  const _AuthModeHitArea({
    required this.label,
    required this.isSelected,
    required this.isEnabled,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isEnabled;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            borderRadius: BorderRadius.circular(StarKidsRadii.full),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: style ?? const TextStyle(),
                child: Text(label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.all(SKSpacing.x4),
      decoration: BoxDecoration(
        color: c.dangerSoft,
        borderRadius: BorderRadius.circular(SKRadius.lg),
        border: Border.all(
          color: c.danger.withValues(alpha: 0.18),
        ),
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
