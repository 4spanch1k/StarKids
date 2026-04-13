import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_icon_sizes.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
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
        final isRegister = _mode == _EmailAuthMode.register;
        final isLoading = _authController.status == MobileAuthStatus.loading;
        final errorMessage = _authController.errorMessage;

        return Scaffold(
          backgroundColor: StarKidsColors.surfaceCanvas,
          resizeToAvoidBottomInset: true,
          body: _AuthCanvas(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
                  final minContentHeight = (constraints.maxHeight -
                          StarKidsSpacing.xl -
                          keyboardInset)
                      .clamp(0.0, double.infinity)
                      .toDouble();

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      StarKidsSpacing.xl,
                      StarKidsSpacing.xl,
                      StarKidsSpacing.xl,
                      StarKidsSpacing.xl + keyboardInset,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: minContentHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _RevealMotion(
                                animation: _entryInterval(0, 0.58),
                                offset: const Offset(0, 0.08),
                                child: _AuthBrandIntro(isRegister: isRegister),
                              ),
                              const SizedBox(height: StarKidsSpacing.x2l),
                              _RevealMotion(
                                animation: _entryInterval(0.16, 0.82),
                                offset: const Offset(0, 0.1),
                                child: _AuthFormCard(
                                  formKey: _formKey,
                                  autovalidateMode: _autovalidateMode,
                                  mode: _mode,
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  confirmPasswordController:
                                      _confirmPasswordController,
                                  isLoading: isLoading,
                                  errorMessage: errorMessage,
                                  isPasswordVisible: _isPasswordVisible,
                                  isConfirmPasswordVisible:
                                      _isConfirmPasswordVisible,
                                  onModeChanged: _setMode,
                                  onSubmit: _submit,
                                  onPasswordVisibilityChanged:
                                      _togglePasswordVisibility,
                                  onConfirmPasswordVisibilityChanged:
                                      _toggleConfirmPasswordVisibility,
                                  emailValidator:
                                      _authController.validateEmailInput,
                                  passwordValidator:
                                      _authController.validatePasswordInput,
                                  confirmationValidator: (value) =>
                                      _authController
                                          .validatePasswordConfirmation(
                                    password: _passwordController.text,
                                    confirmation: value,
                                  ),
                                ),
                              ),
                              const SizedBox(height: StarKidsSpacing.lg),
                              _RevealMotion(
                                animation: _entryInterval(0.34, 1),
                                offset: const Offset(0, 0.06),
                                child: _AuthHintText(isRegister: isRegister),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
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

class _AuthCanvas extends StatelessWidget {
  const _AuthCanvas({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -96,
          child: _DecorativeGlow(
            size: 260,
            color: StarKidsColors.surfaceTertiary.withValues(alpha: 0.82),
          ),
        ),
        Positioned(
          left: -96,
          bottom: 80,
          child: _DecorativeGlow(
            size: 220,
            color: StarKidsColors.brandHighlight.withValues(alpha: 0.26),
          ),
        ),
        child,
      ],
    );
  }
}

class _DecorativeGlow extends StatelessWidget {
  const _DecorativeGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 980),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return IgnorePointer(
          child: Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 28 * (1 - value)),
              child: Transform.scale(
                scale: 0.9 + (value * 0.1),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
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
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  StarKidsColors.brandPrimary,
                  StarKidsColors.brandPrimaryPressed,
                ],
              ),
              borderRadius: BorderRadius.circular(StarKidsRadii.hero),
              boxShadow: StarKidsShadows.depth2,
            ),
            child: const Center(
              child: Text(
                'SK',
                style: TextStyle(
                  color: StarKidsColors.textInverse,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          Text(
            'Star Kids',
            style: textTheme.labelLarge?.copyWith(
              color: StarKidsColors.brandPrimary,
              letterSpacing: 0.8,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(
            'Вход в приложение',
            style: textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(
            isRegister
                ? 'Создайте аккаунт, чтобы заявки и профиль оставались под рукой.'
                : 'Войдите, чтобы продолжить к заявкам, профилю и избранному филиалу.',
            style: textTheme.bodyLarge?.copyWith(
              color: StarKidsColors.textSecondary,
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.md,
        vertical: StarKidsSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
        border: Border.all(color: StarKidsColors.borderDefault),
      ),
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
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: StarKidsColors.textSecondary,
                  ),
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
    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.hero),
        border: Border.all(color: StarKidsColors.borderDefault),
        boxShadow: StarKidsShadows.depth2,
      ),
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
                          color: StarKidsColors.textSecondary,
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
                  boxShadow: isLoading
                      ? const []
                      : [
                          BoxShadow(
                            color: StarKidsColors.brandPrimary
                                .withValues(alpha: 0.22),
                            blurRadius: 26,
                            offset: const Offset(0, 14),
                          ),
                        ],
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
              color: StarKidsColors.textSecondary,
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
    final selectedStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: StarKidsColors.textPrimary,
          fontWeight: FontWeight.w800,
        );
    final idleStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: StarKidsColors.textSecondary,
          fontWeight: FontWeight.w700,
        );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: isEnabled ? 1 : 0.62,
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(StarKidsSpacing.xs),
        decoration: BoxDecoration(
          color: StarKidsColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(StarKidsRadii.full),
          border: Border.all(color: StarKidsColors.borderDefault),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment:
                  _isLogin ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: StarKidsColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(StarKidsRadii.full),
                    boxShadow: [
                      BoxShadow(
                        color:
                            StarKidsColors.textPrimary.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
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
    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.md),
      decoration: BoxDecoration(
        color: StarKidsColors.statusErrorSurface,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(
          color: StarKidsColors.statusError.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: StarKidsColors.surfacePrimary.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(StarKidsRadii.full),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: StarKidsIconSizes.sm,
              color: StarKidsColors.statusError,
            ),
          ),
          const SizedBox(width: StarKidsSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: StarKidsColors.statusError,
                    height: 1.34,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
