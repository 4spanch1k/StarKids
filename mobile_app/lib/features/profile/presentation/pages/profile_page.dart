import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_icon_sizes.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_brand_logo.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_input_field.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../auth/domain/mobile_auth_session.dart';
import '../../../auth/domain/otp_challenge.dart';
import '../../../auth/presentation/controllers/mobile_auth_controller.dart';
import '../../../branches/domain/branch_option.dart';
import '../../../notifications/domain/notification_permission_status.dart';
import '../../../notifications/presentation/controllers/mobile_notifications_controller.dart';
import '../../../requests/presentation/formatters/kz_phone_input_formatter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.notificationsController});

  final MobileNotificationsController? notificationsController;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  MobileAuthController get _authController =>
      ServiceRegistry.mobileAuthController;

  MobileNotificationsController get _notificationsController =>
      widget.notificationsController ??
      ServiceRegistry.mobileNotificationsController;

  Listenable get _pageListenable => Listenable.merge([
    _authController,
    _notificationsController,
    ServiceRegistry.selectedBranchController,
  ]);

  @override
  void initState() {
    super.initState();
    _authController.addListener(_syncControllers);
    unawaited(_notificationsController.bootstrap());
    _syncControllers();
  }

  @override
  void dispose() {
    _authController.removeListener(_syncControllers);
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    final session = _authController.session;
    final challenge = _authController.pendingChallenge;

    if (session != null) {
      _phoneController.text = KzPhoneInputFormatter.formatDisplay(
        session.phone,
      );
      _codeController.clear();
      return;
    }

    if (challenge != null && _phoneController.text.trim().isEmpty) {
      _phoneController.text = KzPhoneInputFormatter.formatDisplay(
        challenge.phone,
      );
      return;
    }

    if (challenge == null &&
        _authController.status == MobileAuthStatus.unauthenticated) {
      _codeController.clear();
    }
  }

  Future<void> _requestOtp() async {
    final isValid = _phoneFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    await _authController.requestOtp(_phoneController.text);
    _codeController.clear();
  }

  Future<void> _verifyOtp() async {
    final isValid = _codeFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    await _authController.verifyOtp(_codeController.text);
  }

  Future<void> _logout() async {
    await _authController.logout();
    _codeController.clear();
  }

  Future<void> _refreshProfile() async {
    await _authController.refreshProfile();
  }

  Future<void> _resendOtp() async {
    await _authController.resendOtp();
    _codeController.clear();
  }

  void _editPhone() {
    _authController.editPhone();
    _codeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pageListenable,
      builder: (context, _) {
        final session = _authController.session;
        final challenge = _authController.pendingChallenge;
        final errorMessage = _authController.errorMessage;
        final selectedBranch =
            ServiceRegistry.selectedBranchController.selectedBranch;

        return Scaffold(
          appBar: AppBar(title: const Text('Профиль')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(StarKidsSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarKidsReveal(
                    child: _ProfileIntroCard(
                      title: session != null
                          ? 'Ваш профиль уже активен'
                          : challenge != null
                          ? 'Подтвердите вход по коду'
                          : 'Войдите по номеру телефона',
                      description: session != null
                          ? 'Номер телефона уже подключен к приложению. Здесь будут собираться ваш профиль и персональный контекст.'
                          : challenge != null
                          ? 'Мы отправили одноразовый код на ваш номер. После подтверждения приложение сохранит вход на этом устройстве.'
                          : 'Войдите по номеру телефона, чтобы сохранить сессию, персональный контекст и подготовить основу для истории заявок.',
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: StarKidsSpacing.lg),
                    StarKidsReveal(
                      delay: starKidsStaggerDelay(1),
                      child: _AuthErrorCard(
                        message: errorMessage,
                        onDismiss: _authController.clearError,
                      ),
                    ),
                  ],
                  const SizedBox(height: StarKidsSpacing.lg),
                  StarKidsContentSwitcher(
                    child: session != null
                        ? _AuthenticatedProfileCard(
                            key: const ValueKey('authenticated-profile-card'),
                            session: session,
                            maskedPhone: _authController.maskPhone(
                              session.phone,
                            ),
                            selectedBranch: selectedBranch,
                            isRefreshing: _authController.isRefreshingProfile,
                            isLoggingOut: _authController.isLoggingOut,
                            onRefresh: _refreshProfile,
                            onLogout: _logout,
                          )
                        : challenge != null
                        ? _OtpVerificationCard(
                            key: const ValueKey('otp-verification-card'),
                            formKey: _codeFormKey,
                            codeController: _codeController,
                            challenge: challenge,
                            maskedPhone: _authController.maskPhone(
                              challenge.phone,
                            ),
                            isLoading:
                                _authController.status ==
                                MobileAuthStatus.verifying,
                            onSubmit: _verifyOtp,
                            onEditPhone: _editPhone,
                            onResendOtp: _resendOtp,
                            validator: _authController.validateOtpCode,
                          )
                        : _PhoneAuthCard(
                            key: const ValueKey('phone-auth-card'),
                            formKey: _phoneFormKey,
                            phoneController: _phoneController,
                            isLoading:
                                _authController.status ==
                                MobileAuthStatus.loading,
                            onSubmit: _requestOtp,
                            validator: _authController.validatePhoneInput,
                          ),
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  StarKidsReveal(
                    delay: starKidsStaggerDelay(2),
                    child: _ProfileNextStepCard(
                      isAuthenticated: session != null,
                      selectedBranchLabel: selectedBranch.name,
                      onOpenHistory: () =>
                          Navigator.of(context).pushNamed(AppRoutes.myRequests),
                    ),
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  StarKidsReveal(
                    delay: starKidsStaggerDelay(3),
                    child: _NotificationsStatusCard(
                      status: _notificationsController.status,
                      onOpenStatus: () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.notifications),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileIntroCard extends StatelessWidget {
  const _ProfileIntroCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(color: StarKidsColors.borderDefault),
        boxShadow: StarKidsShadows.depth1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 88,
            height: 88,
            child: StarKidsBrandLogo(logoSize: 78),
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: StarKidsSpacing.md,
              vertical: StarKidsSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: StarKidsColors.brandHighlight,
              borderRadius: BorderRadius.circular(StarKidsRadii.full),
            ),
            child: Text(
              'Персональный контекст',
              style: textTheme.labelMedium?.copyWith(
                color: StarKidsColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: StarKidsSpacing.md),
          Text(title, style: textTheme.headlineMedium),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(description, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _AuthErrorCard extends StatelessWidget {
  const _AuthErrorCard({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: StarKidsColors.statusError.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(
          color: StarKidsColors.statusError.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: StarKidsColors.statusError,
            size: StarKidsIconSizes.md,
          ),
          const SizedBox(width: StarKidsSpacing.md),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: StarKidsColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: StarKidsSpacing.sm),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _PhoneAuthCard extends StatelessWidget {
  const _PhoneAuthCard({
    super.key,
    required this.formKey,
    required this.phoneController,
    required this.isLoading,
    required this.onSubmit,
    required this.validator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final bool isLoading;
  final Future<void> Function() onSubmit;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return _AuthCardShell(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Номер телефона',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: StarKidsSpacing.sm),
            Text(
              'Этот номер станет основой для персонального входа на устройстве.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsInputField(
              controller: phoneController,
              label: 'Телефон',
              hintText: '+7 777 123 45 67',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.phone_rounded,
              validator: validator,
              inputFormatters: [KzPhoneInputFormatter()],
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsButton.primary(
              label: 'Получить код',
              onPressed: isLoading ? null : () => onSubmit(),
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpVerificationCard extends StatelessWidget {
  const _OtpVerificationCard({
    super.key,
    required this.formKey,
    required this.codeController,
    required this.challenge,
    required this.maskedPhone,
    required this.isLoading,
    required this.onSubmit,
    required this.onEditPhone,
    required this.onResendOtp,
    required this.validator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController codeController;
  final OtpChallenge challenge;
  final String maskedPhone;
  final bool isLoading;
  final Future<void> Function() onSubmit;
  final VoidCallback onEditPhone;
  final Future<void> Function() onResendOtp;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final expiresAt = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(challenge.expiresAt));

    return _AuthCardShell(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Код из SMS', style: textTheme.titleLarge),
            const SizedBox(height: StarKidsSpacing.sm),
            Text(
              'Код отправлен на $maskedPhone. Он действует примерно до $expiresAt.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsInputField(
              controller: codeController,
              label: 'Код подтверждения',
              hintText: 'Введите код',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.password_rounded,
              validator: validator,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsButton.primary(
              label: 'Подтвердить вход',
              onPressed: isLoading ? null : () => onSubmit(),
              isLoading: isLoading,
            ),
            const SizedBox(height: StarKidsSpacing.md),
            Row(
              children: [
                Expanded(
                  child: StarKidsButton.secondary(
                    label: 'Изменить номер',
                    onPressed: isLoading ? null : onEditPhone,
                  ),
                ),
                const SizedBox(width: StarKidsSpacing.sm),
                Expanded(
                  child: StarKidsButton.ghost(
                    label: 'Отправить код еще раз',
                    onPressed: isLoading ? null : () => onResendOtp(),
                    expand: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthenticatedProfileCard extends StatelessWidget {
  const _AuthenticatedProfileCard({
    super.key,
    required this.session,
    required this.maskedPhone,
    required this.selectedBranch,
    required this.isRefreshing,
    required this.isLoggingOut,
    required this.onRefresh,
    required this.onLogout,
  });

  final MobileAuthSession session;
  final String maskedPhone;
  final BranchOption selectedBranch;
  final bool isRefreshing;
  final bool isLoggingOut;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final verifiedDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(session.verifiedAt);
    final displayPhone = KzPhoneInputFormatter.formatDisplay(
      session.user?.phone ?? session.phone,
    );

    return _AuthCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Профиль подключен', style: textTheme.titleLarge),
              ),
              if (isRefreshing)
                const SizedBox(
                  width: StarKidsSpacing.lg,
                  height: StarKidsSpacing.lg,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(
            'Номер $maskedPhone подтвержден. Вход сохранен на этом устройстве и будет использоваться для персонального контекста.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          _ProfileFactRow(label: 'Телефон', value: displayPhone),
          const SizedBox(height: StarKidsSpacing.md),
          _ProfileFactRow(label: 'Текущий филиал', value: selectedBranch.name),
          const SizedBox(height: StarKidsSpacing.md),
          _ProfileFactRow(
            label: 'Адрес филиала',
            value: selectedBranch.address,
          ),
          const SizedBox(height: StarKidsSpacing.md),
          _ProfileFactRow(label: 'Вход подтвержден', value: verifiedDate),
          const SizedBox(height: StarKidsSpacing.md),
          _ProfileFactRow(
            label: 'Состояние',
            value: isRefreshing ? 'Обновляем профиль' : 'Активная сессия',
          ),
          const SizedBox(height: StarKidsSpacing.xl),
          Row(
            children: [
              Expanded(
                child: StarKidsButton.secondary(
                  label: 'Обновить профиль',
                  onPressed: isRefreshing || isLoggingOut
                      ? null
                      : () => onRefresh(),
                ),
              ),
              const SizedBox(width: StarKidsSpacing.sm),
              Expanded(
                child: StarKidsButton.primary(
                  label: 'Выйти',
                  onPressed: isRefreshing || isLoggingOut
                      ? null
                      : () => onLogout(),
                  isLoading: isLoggingOut,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileNextStepCard extends StatelessWidget {
  const _ProfileNextStepCard({
    required this.isAuthenticated,
    required this.selectedBranchLabel,
    required this.onOpenHistory,
  });

  final bool isAuthenticated;
  final String selectedBranchLabel;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: StarKidsColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(color: StarKidsColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAuthenticated
                ? 'Профиль уже привязан к номеру телефона. Здесь можно открыть историю ваших заявок для филиала $selectedBranchLabel.'
                : 'После входа по номеру телефона приложение покажет только ваши заявки и их актуальный статус.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: StarKidsSpacing.md),
          StarKidsButton.secondary(
            label: 'Мои заявки',
            onPressed: onOpenHistory,
          ),
        ],
      ),
    );
  }
}

class _NotificationsStatusCard extends StatelessWidget {
  const _NotificationsStatusCard({
    required this.status,
    required this.onOpenStatus,
  });

  final NotificationPermissionStatus status;
  final VoidCallback onOpenStatus;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: StarKidsColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(color: StarKidsColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Уведомления', style: textTheme.titleLarge),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(_descriptionForStatus(status), style: textTheme.bodyMedium),
          const SizedBox(height: StarKidsSpacing.md),
          _ProfileFactRow(label: 'Состояние', value: _labelForStatus(status)),
          const SizedBox(height: StarKidsSpacing.md),
          StarKidsButton.secondary(
            label: 'Статус уведомлений',
            onPressed: onOpenStatus,
          ),
        ],
      ),
    );
  }

  String _labelForStatus(NotificationPermissionStatus status) {
    return switch (status) {
      NotificationPermissionStatus.unknown => 'Не запрашивалось',
      NotificationPermissionStatus.granted => 'Разрешено',
      NotificationPermissionStatus.denied => 'Отключено',
      NotificationPermissionStatus.unavailable => 'Недоступно',
    };
  }

  String _descriptionForStatus(NotificationPermissionStatus status) {
    return switch (status) {
      NotificationPermissionStatus.unknown =>
        'Разрешение на уведомления еще не запрашивалось. Сейчас доступна '
            'только foundation-подготовка: backend registration устройства '
            'еще не подключена.',
      NotificationPermissionStatus.granted =>
        'Разрешение на уведомления уже выдано, но push delivery пока не '
            'активна: backend не регистрирует устройство.',
      NotificationPermissionStatus.denied =>
        'Разрешение на уведомления отключено. Его можно проверить и '
            'изменить отдельно, но push delivery пока еще не подключена.',
      NotificationPermissionStatus.unavailable =>
        'В этой сборке управление уведомлениями недоступно, а backend '
            'registration устройства пока отсутствует.',
    };
  }
}

class _AuthCardShell extends StatelessWidget {
  const _AuthCardShell({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

class _ProfileFactRow extends StatelessWidget {
  const _ProfileFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: StarKidsColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: StarKidsSpacing.md),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
