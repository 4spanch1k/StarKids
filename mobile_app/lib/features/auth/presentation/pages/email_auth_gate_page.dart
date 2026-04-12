import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_icon_sizes.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_input_field.dart';
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

class _EmailAuthGatePageState extends State<EmailAuthGatePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _EmailAuthMode _mode = _EmailAuthMode.login;

  MobileAuthController get _authController =>
      ServiceRegistry.mobileAuthController;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
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
    });
    _authController.clearError();
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
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(StarKidsSpacing.xl),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - StarKidsSpacing.x2l,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: StarKidsSpacing.x2l),
                        const _AuthBrandIntro(),
                        const SizedBox(height: StarKidsSpacing.x2l),
                        _AuthFormCard(
                          formKey: _formKey,
                          mode: _mode,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          confirmPasswordController: _confirmPasswordController,
                          isLoading: isLoading,
                          errorMessage: errorMessage,
                          onModeChanged: _setMode,
                          onSubmit: _submit,
                          emailValidator: _authController.validateEmailInput,
                          passwordValidator:
                              _authController.validatePasswordInput,
                          confirmationValidator: (value) =>
                              _authController.validatePasswordConfirmation(
                            password: _passwordController.text,
                            confirmation: value,
                          ),
                        ),
                        const SizedBox(height: StarKidsSpacing.lg),
                        Text(
                          isRegister
                              ? 'После регистрации вход сохранится на этом устройстве.'
                              : 'Если аккаунта еще нет, переключитесь на регистрацию.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _AuthBrandIntro extends StatelessWidget {
  const _AuthBrandIntro();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: StarKidsColors.brandPrimary,
            borderRadius: BorderRadius.circular(StarKidsRadii.xl),
            boxShadow: StarKidsShadows.depth1,
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
            letterSpacing: 0.6,
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
          'Авторизуйтесь, чтобы сохранять заявки, профиль и персональный контекст.',
          style: textTheme.bodyLarge?.copyWith(
            color: StarKidsColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AuthFormCard extends StatelessWidget {
  const _AuthFormCard({
    required this.formKey,
    required this.mode,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.errorMessage,
    required this.onModeChanged,
    required this.onSubmit,
    required this.emailValidator,
    required this.passwordValidator,
    required this.confirmationValidator,
  });

  final GlobalKey<FormState> formKey;
  final _EmailAuthMode mode;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<_EmailAuthMode> onModeChanged;
  final Future<void> Function() onSubmit;
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
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(color: StarKidsColors.borderDefault),
        boxShadow: StarKidsShadows.depth1,
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AuthModeSwitch(
              mode: mode,
              onChanged: isLoading ? null : onModeChanged,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: StarKidsSpacing.lg),
              _AuthErrorBanner(message: errorMessage!),
            ],
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsInputField(
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
            StarKidsInputField(
              controller: passwordController,
              label: 'Пароль',
              hintText: 'Минимум 8 символов',
              textInputAction:
                  _isRegister ? TextInputAction.next : TextInputAction.done,
              prefixIcon: Icons.lock_rounded,
              enabled: !isLoading,
              obscureText: true,
              validator: passwordValidator,
              autofillHints: const [AutofillHints.password],
            ),
            if (_isRegister) ...[
              const SizedBox(height: StarKidsSpacing.md),
              StarKidsInputField(
                controller: confirmPasswordController,
                label: 'Подтверждение пароля',
                hintText: 'Повторите пароль',
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.verified_user_rounded,
                enabled: !isLoading,
                obscureText: true,
                validator: confirmationValidator,
                autofillHints: const [AutofillHints.newPassword],
              ),
            ],
            const SizedBox(height: StarKidsSpacing.xl),
            StarKidsButton.primary(
              label: _isRegister ? 'Зарегистрироваться' : 'Войти',
              onPressed: isLoading ? null : () => onSubmit(),
              isLoading: isLoading,
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_EmailAuthMode>(
      segments: const [
        ButtonSegment<_EmailAuthMode>(
          value: _EmailAuthMode.login,
          label: Text('Вход'),
        ),
        ButtonSegment<_EmailAuthMode>(
          value: _EmailAuthMode.register,
          label: Text('Регистрация'),
        ),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged:
          onChanged == null ? null : (selection) => onChanged!(selection.first),
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
        color: StarKidsColors.statusError.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(
          color: StarKidsColors.statusError.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: StarKidsIconSizes.sm,
            color: StarKidsColors.statusError,
          ),
          const SizedBox(width: StarKidsSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
