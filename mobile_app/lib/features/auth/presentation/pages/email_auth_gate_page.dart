import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/sk_tokens.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/sk_fade.dart';
import '../../../../core/design_system/widgets/sk_field.dart';
import '../controllers/mobile_auth_controller.dart';

class EmailAuthGatePage extends StatefulWidget {
  const EmailAuthGatePage({super.key});

  @override
  State<EmailAuthGatePage> createState() => _EmailAuthGatePageState();
}

class _EmailAuthGatePageState extends State<EmailAuthGatePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  late final AnimationController _entryController;
  Timer? _resendTimer;
  DateTime? _resendAvailableAt;

  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

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
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
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

    if (_authController.pendingChallenge != null) {
      await _authController.verifyOtp(_otpController.text);
      return;
    }

    await _authController.requestOtp(_phoneController.text);
    _startResendCountdown();
  }

  void _startResendCountdown() {
    final challenge = _authController.pendingChallenge;
    if (challenge == null || challenge.resendAfter <= Duration.zero) return;
    _resendAvailableAt = DateTime.now().add(challenge.resendAfter);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendAvailableAt == null) {
        timer.cancel();
        return;
      }
      if (DateTime.now().isAfter(_resendAvailableAt!)) {
        timer.cancel();
      }
      setState(() {});
    });
  }

  void _editPhone() {
    unawaited(HapticFeedback.selectionClick());
    _otpController.clear();
    _authController.editPhone();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        final c = SKTheme.of(context).colors;
        final isLoading = _authController.status == MobileAuthStatus.loading;
        final isVerifying =
            _authController.status == MobileAuthStatus.verifying;
        final challenge = _authController.pendingChallenge;
        final isCodeStep = challenge != null;
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
                    final keyboardInset = MediaQuery.viewInsetsOf(
                      context,
                    ).bottom;
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
                        constraints: BoxConstraints(
                          minHeight: minContentHeight,
                        ),
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
                                  const SkFade(
                                    delayMs: 120,
                                    child: _RedesignAuthIntro(),
                                  ),
                                  const SizedBox(height: SK.s6),
                                  if (isCodeStep)
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: isLoading || isVerifying
                                              ? null
                                              : _editPhone,
                                          icon: const Icon(Icons.arrow_back),
                                          tooltip: 'Изменить номер',
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Код для ${_authController.maskPhone(challenge.phone)}',
                                            style: SKTextStyles.body.copyWith(
                                              color: c.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: SK.s4),
                                  if (errorMessage != null) ...[
                                    _AuthErrorBanner(message: errorMessage),
                                    const SizedBox(height: SK.s4),
                                  ],
                                  SkFade(
                                    delayMs: 280,
                                    child: isCodeStep
                                        ? SkField(
                                            key: const ValueKey(
                                              'auth-otp-field',
                                            ),
                                            controller: _otpController,
                                            label: 'Код подтверждения',
                                            hintText: '6 цифр из SMS',
                                            icon: Icons.password_rounded,
                                            keyboardType: TextInputType.number,
                                            autofillHints: const [
                                              AutofillHints.oneTimeCode,
                                            ],
                                            textInputAction:
                                                TextInputAction.done,
                                            maxLength: 6,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            autocorrect: false,
                                            enableSuggestions: false,
                                            validator:
                                                _authController.validateOtpCode,
                                          )
                                        : SkField(
                                            key: const ValueKey(
                                              'auth-phone-field',
                                            ),
                                            controller: _phoneController,
                                            label: 'Номер телефона',
                                            hintText: '+7 777 123 45 67',
                                            icon: Icons.phone_outlined,
                                            keyboardType: TextInputType.phone,
                                            textInputAction:
                                                TextInputAction.done,
                                            autofillHints: const [
                                              AutofillHints.telephoneNumber,
                                            ],
                                            autocorrect: false,
                                            validator: _authController
                                                .validatePhoneInput,
                                          ),
                                  ),
                                  if (isCodeStep) ...[
                                    const SizedBox(height: SK.s3),
                                    Text(
                                      'Введите код подтверждения из SMS. Он действует ${challenge.expiresIn.inMinutes} мин.',
                                      style: SKTextStyles.small.copyWith(
                                        color: c.textTertiary,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: SK.s3),
                                    Builder(
                                      builder: (context) {
                                        final remaining = _resendAvailableAt
                                                ?.difference(DateTime.now())
                                                .inSeconds ??
                                            0;
                                        final cooldown = remaining > 0
                                            ? remaining
                                            : 0;
                                        return TextButton(
                                          onPressed: isLoading ||
                                                  isVerifying ||
                                                  cooldown > 0
                                              ? null
                                              : () async {
                                                  await _authController
                                                      .resendOtp();
                                                  _startResendCountdown();
                                                },
                                          child: Text(
                                            cooldown > 0
                                                ? 'Повторить через $cooldown сек.'
                                                : 'Отправить код ещё раз',
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: SK.s5),
                                  SkFade(
                                    delayMs: 440,
                                    child: PrimaryButton(
                                      label: isCodeStep
                                          ? 'Подтвердить и войти'
                                          : 'Получить код',
                                      icon: Icons.arrow_forward_rounded,
                                      onPressed: isLoading || isVerifying
                                          ? null
                                          : () async {
                                              await Future<void>.delayed(
                                                const Duration(
                                                  milliseconds: 250,
                                                ),
                                              );
                                              await _submit();
                                            },
                                    ),
                                  ),
                                  const SizedBox(height: SK.s5),
                                  const _RedesignSessionHint(),
                                  const SizedBox(height: SK.s8),
                                  Text(
                                    'После входа вы сможете настроить профиль семьи.',
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
              'Boom Bala',
              style: SKTextStyles.h3.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Семейный развлекательный центр',
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
  const _RedesignAuthIntro();

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Column(
        key: const ValueKey('phone-otp-auth'),
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
              'Войдите по номеру телефона — профиль семьи и заявки будут под рукой.',
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
            child: Icon(Icons.error_outline_rounded, size: 16, color: c.danger),
          ),
          const SizedBox(width: SKSpacing.x4),
          Expanded(
            child: Text(
              message,
              style: SKTextStyles.body.copyWith(color: c.danger, height: 1.34),
            ),
          ),
        ],
      ),
    );
  }
}
