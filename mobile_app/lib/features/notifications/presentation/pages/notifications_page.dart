import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_icon_sizes.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../domain/notification_permission_status.dart';
import '../controllers/mobile_notifications_controller.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    this.notificationsController,
  });

  final MobileNotificationsController? notificationsController;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  MobileNotificationsController get _controller =>
      widget.notificationsController ??
      ServiceRegistry.mobileNotificationsController;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final status = _controller.status;
        final action = _primaryActionForStatus(status);
        final errorMessage = _controller.errorMessage;

        return Scaffold(
          appBar: AppBar(title: const Text('Уведомления')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(StarKidsSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NotificationsSummaryCard(
                    status: status,
                    isLoading: _controller.isLoading,
                    actionLabel: action?.label,
                    isActionLoading: _controller.isRequestingPermission ||
                        _controller.isOpeningSettings,
                    onActionTap: action?.onTap,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: StarKidsSpacing.lg),
                    _NotificationsErrorCard(
                      message: errorMessage,
                      onDismiss: _controller.clearError,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _NotificationsAction? _primaryActionForStatus(
    NotificationPermissionStatus status,
  ) {
    return switch (status) {
      NotificationPermissionStatus.unknown => _NotificationsAction(
          label: 'Разрешить уведомления',
          onTap: _controller.requestPermission,
        ),
      NotificationPermissionStatus.granted => _NotificationsAction(
          label: 'Открыть настройки приложения',
          onTap: _controller.openSystemSettings,
        ),
      NotificationPermissionStatus.denied => _NotificationsAction(
          label: 'Открыть настройки приложения',
          onTap: _controller.openSystemSettings,
        ),
      NotificationPermissionStatus.unavailable => null,
    };
  }
}

class _NotificationsSummaryCard extends StatelessWidget {
  const _NotificationsSummaryCard({
    required this.status,
    required this.isLoading,
    required this.actionLabel,
    required this.isActionLoading,
    required this.onActionTap,
  });

  final NotificationPermissionStatus status;
  final bool isLoading;
  final String? actionLabel;
  final bool isActionLoading;
  final Future<void> Function()? onActionTap;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Статус уведомлений',
                  style: textTheme.headlineMedium,
                ),
              ),
              _NotificationStatusChip(status: status),
            ],
          ),
          const SizedBox(height: StarKidsSpacing.md),
          Text(
            _descriptionForStatus(status),
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: StarKidsSpacing.xl),
          _NotificationFactRow(
            label: 'Системное разрешение',
            value: _labelForStatus(status),
          ),
          const SizedBox(height: StarKidsSpacing.md),
          const _NotificationFactRow(
            label: 'Регистрация устройства',
            value: 'Не подключена',
          ),
          const SizedBox(height: StarKidsSpacing.md),
          const _NotificationFactRow(
            label: 'Токен уведомлений',
            value: 'Не используется',
          ),
          if (isLoading) ...[
            const SizedBox(height: StarKidsSpacing.lg),
            const LinearProgressIndicator(),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: StarKidsSpacing.xl),
            StarKidsButton.primary(
              label: actionLabel!,
              onPressed: onActionTap == null ? null : () => onActionTap!(),
              isLoading: isActionLoading,
            ),
          ],
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
        'Приложение еще не запрашивало системное разрешение на уведомления. '
            'Регистрация устройства и отправка уведомлений пока не подключены.',
      NotificationPermissionStatus.granted =>
        'Системное разрешение уже выдано. Отправка уведомлений будет подключена '
            'отдельным шагом.',
      NotificationPermissionStatus.denied =>
        'Системное разрешение отключено. Без него приложение не сможет '
            'показывать уведомления, когда отправка будет подключена.',
      NotificationPermissionStatus.unavailable =>
        'В этой сборке или на этой платформе управление уведомлениями '
            'недоступно. Регистрация устройства пока не используется.',
    };
  }
}

class _NotificationsErrorCard extends StatelessWidget {
  const _NotificationsErrorCard({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
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
          Expanded(child: Text(message)),
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

class _NotificationStatusChip extends StatelessWidget {
  const _NotificationStatusChip({
    required this.status,
  });

  final NotificationPermissionStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = switch (status) {
      NotificationPermissionStatus.unknown => (
          background: StarKidsColors.brandHighlight,
          foreground: StarKidsColors.textPrimary,
        ),
      NotificationPermissionStatus.granted => (
          background: StarKidsColors.statusSuccess.withValues(alpha: 0.14),
          foreground: StarKidsColors.statusSuccess,
        ),
      NotificationPermissionStatus.denied => (
          background: StarKidsColors.statusError.withValues(alpha: 0.12),
          foreground: StarKidsColors.statusError,
        ),
      NotificationPermissionStatus.unavailable => (
          background: StarKidsColors.surfaceSecondary,
          foreground: StarKidsColors.textSecondary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.md,
        vertical: StarKidsSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
      ),
      child: Text(
        switch (status) {
          NotificationPermissionStatus.unknown => 'Не запрашивалось',
          NotificationPermissionStatus.granted => 'Разрешено',
          NotificationPermissionStatus.denied => 'Отключено',
          NotificationPermissionStatus.unavailable => 'Недоступно',
        },
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: palette.foreground,
            ),
      ),
    );
  }
}

class _NotificationFactRow extends StatelessWidget {
  const _NotificationFactRow({
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

class _NotificationsAction {
  const _NotificationsAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final Future<void> Function() onTap;
}
