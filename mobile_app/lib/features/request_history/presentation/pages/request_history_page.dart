import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../domain/request_history_item.dart';
import '../controllers/request_history_controller.dart';

class RequestHistoryPage extends StatefulWidget {
  const RequestHistoryPage({
    super.key,
    this.controller,
    this.onOpenProfile,
  });

  final RequestHistoryController? controller;
  final VoidCallback? onOpenProfile;

  @override
  State<RequestHistoryPage> createState() => _RequestHistoryPageState();
}

class _RequestHistoryPageState extends State<RequestHistoryPage> {
  late final RequestHistoryController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        RequestHistoryController(
          repository: ServiceRegistry.requestHistoryRepository,
        );
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() {
    return _controller.load();
  }

  void _openProfile() {
    final customHandler = widget.onOpenProfile;
    if (customHandler != null) {
      customHandler();
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.profile, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Мои заявки'),
            actions: [
              if (_controller.status !=
                  RequestHistoryViewStatus.unauthenticated)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Обновить',
                  onPressed: _controller.isLoading ? null : _reload,
                ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(StarKidsSpacing.xl),
              child: _buildBody(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_controller.status) {
      case RequestHistoryViewStatus.idle:
      case RequestHistoryViewStatus.loading:
        return const _HistoryStateView(
          icon: Icons.history_rounded,
          title: 'Загружаем заявки',
          description:
              'Подождите немного, мы получаем историю ваших обращений.',
          isLoading: true,
        );
      case RequestHistoryViewStatus.unauthenticated:
        return _HistoryStateView(
          icon: Icons.lock_outline_rounded,
          title: 'История доступна после входа',
          description:
              'Войдите по номеру телефона в профиле, чтобы увидеть только свои заявки.',
          buttonLabel: 'Войти по номеру',
          onPressed: _openProfile,
        );
      case RequestHistoryViewStatus.empty:
        return _HistoryStateView(
          icon: Icons.inbox_outlined,
          title: 'Пока нет заявок',
          description:
              'Когда вы отправите заявку из приложения, она появится на этом экране.',
          buttonLabel: 'Обновить',
          onPressed: _reload,
        );
      case RequestHistoryViewStatus.error:
        return _HistoryStateView(
          icon: Icons.cloud_off_rounded,
          title: 'Не удалось загрузить историю',
          description: _controller.errorMessage ??
              'Проверьте интернет и попробуйте снова.',
          buttonLabel: 'Повторить',
          onPressed: _reload,
        );
      case RequestHistoryViewStatus.loaded:
        return ListView.separated(
          itemCount: _controller.items.length + 1,
          separatorBuilder: (_, __) =>
              const SizedBox(height: StarKidsSpacing.md),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _HistoryHeader(total: _controller.total);
            }

            final item = _controller.items[index - 1];
            return _RequestHistoryCard(item: item);
          },
        );
    }
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.total,
  });

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: StarKidsColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(color: StarKidsColors.borderDefault),
      ),
      child: Text(
        total == 1 ? 'Найдена 1 заявка.' : 'Найдено $total заявок.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

class _RequestHistoryCard extends StatelessWidget {
  const _RequestHistoryCard({
    required this.item,
  });

  final RequestHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final createdAtLabel = _formatCreatedAt(context, item.createdAt);
    final details = _buildDetails(context, item);

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.type.label, style: textTheme.titleMedium),
                    const SizedBox(height: StarKidsSpacing.xs),
                    Text(
                      'Создана $createdAtLabel',
                      style: textTheme.bodySmall?.copyWith(
                        color: StarKidsColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _HistoryStatusChip(label: item.status.label),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: StarKidsSpacing.lg),
            ...details,
          ],
          const SizedBox(height: StarKidsSpacing.lg),
          Text(
            item.hasNotes ? item.notes!.trim() : item.type.fallbackHistoryNotes,
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetails(BuildContext context, RequestHistoryItem item) {
    final rows = <Widget>[];

    if (item.requestedDate != null) {
      rows.add(
        _HistoryFactRow(
          label: 'Дата праздника',
          value: MaterialLocalizations.of(
            context,
          ).formatMediumDate(item.requestedDate!),
        ),
      );
    }

    if (item.guestCount != null) {
      rows.add(
        _HistoryFactRow(
          label: 'Гостей',
          value: '${item.guestCount}',
        ),
      );
    }

    if (item.branch != null) {
      rows.add(
        _HistoryFactRow(
          label: 'Филиал',
          value: item.branch!.name,
        ),
      );
    }

    if (item.package != null) {
      rows.add(
        _HistoryFactRow(
          label: 'Пакет',
          value: item.package!.name,
        ),
      );
    }

    if (rows.isEmpty) {
      return const [];
    }

    final widgets = <Widget>[];
    for (var index = 0; index < rows.length; index += 1) {
      widgets.add(rows[index]);
      if (index < rows.length - 1) {
        widgets.add(const SizedBox(height: StarKidsSpacing.sm));
      }
    }

    return widgets;
  }

  String _formatCreatedAt(BuildContext context, DateTime createdAt) {
    final localizations = MaterialLocalizations.of(context);
    final localDateTime = createdAt.toLocal();
    return '${localizations.formatMediumDate(localDateTime)} • ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(localDateTime), alwaysUse24HourFormat: true)}';
  }
}

class _HistoryFactRow extends StatelessWidget {
  const _HistoryFactRow({
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
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _HistoryStatusChip extends StatelessWidget {
  const _HistoryStatusChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.md,
        vertical: StarKidsSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: StarKidsColors.brandHighlight,
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: StarKidsColors.textPrimary,
            ),
      ),
    );
  }
}

class _HistoryStateView extends StatelessWidget {
  const _HistoryStateView({
    required this.icon,
    required this.title,
    required this.description,
    this.buttonLabel,
    this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? buttonLabel;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(StarKidsSpacing.xl),
        decoration: BoxDecoration(
          color: StarKidsColors.surfacePrimary,
          borderRadius: BorderRadius.circular(StarKidsRadii.xl),
          border: Border.all(color: StarKidsColors.borderDefault),
          boxShadow: StarKidsShadows.depth1,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                icon,
                size: 36,
                color: StarKidsColors.brandPrimary,
              ),
            const SizedBox(height: StarKidsSpacing.lg),
            Text(title,
                style: textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: StarKidsSpacing.sm),
            Text(
              description,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: StarKidsSpacing.lg),
              StarKidsButton.primary(
                label: buttonLabel!,
                onPressed: isLoading ? null : onPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
