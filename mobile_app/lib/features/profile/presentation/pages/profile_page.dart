import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_icon_sizes.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../auth/domain/mobile_auth_session.dart';
import '../../../auth/presentation/controllers/mobile_auth_controller.dart';
import '../../../branches/domain/branch_option.dart';
import '../../../notifications/domain/notification_permission_status.dart';
import '../../../notifications/presentation/controllers/mobile_notifications_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.notificationsController,
  });

  final MobileNotificationsController? notificationsController;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
    unawaited(_notificationsController.bootstrap());
  }

  Future<void> _logout() async {
    await _authController.logout();
  }

  Future<void> _refreshProfile() async {
    await _authController.refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pageListenable,
      builder: (context, _) {
        final session = _authController.session;
        final selectedBranch =
            ServiceRegistry.selectedBranchController.selectedBranch;
        final errorMessage = _authController.errorMessage;

        return Scaffold(
          appBar: AppBar(title: const Text('Профиль')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(StarKidsSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileIntroCard(
                    title: session == null
                        ? 'Вход не выполнен'
                        : 'Ваш профиль активен',
                    description: session == null
                        ? 'Чтобы пользоваться приложением, вернитесь на экран входа и авторизуйтесь по email.'
                        : 'Здесь хранится ваш аккаунт, выбранный филиал и быстрый переход к истории заявок.',
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: StarKidsSpacing.lg),
                    _AuthErrorCard(
                      message: errorMessage,
                      onDismiss: _authController.clearError,
                    ),
                  ],
                  const SizedBox(height: StarKidsSpacing.lg),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: session == null
                        ? _UnauthenticatedProfileCard(
                            key: const ValueKey('unauthenticated-profile'),
                            onLogout: _logout,
                          )
                        : _AuthenticatedProfileCard(
                            key: const ValueKey('authenticated-profile-card'),
                            session: session,
                            selectedBranch: selectedBranch,
                            isRefreshing: _authController.isRefreshingProfile,
                            isLoggingOut: _authController.isLoggingOut,
                            onRefresh: _refreshProfile,
                            onLogout: _logout,
                          ),
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  _ProfileNextStepCard(
                    selectedBranchLabel: selectedBranch.name,
                    onOpenHistory: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.myRequests),
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  _NotificationsStatusCard(
                    status: _notificationsController.status,
                    onOpenStatus: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.notifications),
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
  const _ProfileIntroCard({
    required this.title,
    required this.description,
  });

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
              'Аккаунт',
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
  const _AuthErrorCard({
    required this.message,
    required this.onDismiss,
  });

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

class _UnauthenticatedProfileCard extends StatelessWidget {
  const _UnauthenticatedProfileCard({
    super.key,
    required this.onLogout,
  });

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return _AuthCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сессия не активна',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(
            'Приложение откроет экран входа. Авторизуйтесь по email, чтобы продолжить.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          StarKidsButton.primary(
            label: 'Перейти ко входу',
            onPressed: () => onLogout(),
          ),
        ],
      ),
    );
  }
}

class _AuthenticatedProfileCard extends StatelessWidget {
  const _AuthenticatedProfileCard({
    super.key,
    required this.session,
    required this.selectedBranch,
    required this.isRefreshing,
    required this.isLoggingOut,
    required this.onRefresh,
    required this.onLogout,
  });

  final MobileAuthSession session;
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
    final email = session.user?.email ?? session.email ?? 'Email не указан';
    final phone = session.user?.phone ?? session.phone;

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
            'Вход сохранен на этом устройстве. Сессия проверяется через сервер при запуске приложения.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          _ProfileFactRow(
            label: 'Email',
            value: email,
          ),
          if (phone != null && phone.trim().isNotEmpty) ...[
            const SizedBox(height: StarKidsSpacing.md),
            _ProfileFactRow(
              label: 'Телефон',
              value: phone,
            ),
          ],
          const SizedBox(height: StarKidsSpacing.md),
          _ProfileFactRow(
            label: 'Текущий филиал',
            value: selectedBranch.name,
          ),
          const SizedBox(height: StarKidsSpacing.md),
          _ProfileFactRow(
            label: 'Вход выполнен',
            value: verifiedDate,
          ),
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
                  label: 'Обновить',
                  onPressed:
                      isRefreshing || isLoggingOut ? null : () => onRefresh(),
                ),
              ),
              const SizedBox(width: StarKidsSpacing.sm),
              Expanded(
                child: StarKidsButton.primary(
                  label: 'Выйти',
                  onPressed:
                      isRefreshing || isLoggingOut ? null : () => onLogout(),
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
    required this.selectedBranchLabel,
    required this.onOpenHistory,
  });

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
            'История заявок привязана к вашему аккаунту. Сейчас выбран филиал $selectedBranchLabel.',
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
          Text(
            _descriptionForStatus(status),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: StarKidsSpacing.md),
          _ProfileFactRow(
            label: 'Состояние',
            value: _labelForStatus(status),
          ),
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
        'Разрешение на уведомления еще не запрашивалось. Сейчас доступна базовая подготовка, отправка уведомлений будет подключена отдельно.',
      NotificationPermissionStatus.granted =>
        'Разрешение на уведомления уже выдано. Отправка уведомлений будет подключена отдельным шагом.',
      NotificationPermissionStatus.denied =>
        'Разрешение на уведомления отключено. Его можно проверить и изменить отдельно.',
      NotificationPermissionStatus.unavailable =>
        'В этой сборке управление уведомлениями недоступно.',
    };
  }
}

class _AuthCardShell extends StatelessWidget {
  const _AuthCardShell({
    required this.child,
  });

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
  const _ProfileFactRow({
    required this.label,
    required this.value,
  });

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
