import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../requests/domain/request_type.dart';
import '../../domain/request_history_item.dart';
import '../controllers/request_history_controller.dart';

class RequestHistoryPage extends StatefulWidget {
  const RequestHistoryPage({super.key, this.controller, this.onOpenProfile});

  final RequestHistoryController? controller;
  final VoidCallback? onOpenProfile;

  @override
  State<RequestHistoryPage> createState() => _RequestHistoryPageState();
}

class _RequestHistoryPageState extends State<RequestHistoryPage> {
  late final RequestHistoryController _controller;
  late final bool _ownsController;
  RequestType? _activeFilter;

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
          appBar: GlassAppBar(
            leading: GlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Назад',
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Мои заявки',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: _controller.status !=
                    RequestHistoryViewStatus.unauthenticated
                ? GlassIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Обновить',
                    onPressed: _controller.isLoading ? null : _reload,
                  )
                : null,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(StarKidsSpacing.xl),
              child: StarKidsContentSwitcher(child: _buildBody(context)),
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
          key: ValueKey('request-history-loading'),
          icon: Icons.history_rounded,
          title: 'Загружаем заявки',
          description:
              'Подождите немного, мы получаем историю ваших обращений.',
          isLoading: true,
        );
      case RequestHistoryViewStatus.unauthenticated:
        return _HistoryStateView(
          key: const ValueKey('request-history-unauthenticated'),
          icon: Icons.lock_outline_rounded,
          title: 'История доступна после входа',
          description: 'Войдите по email, чтобы увидеть только свои заявки.',
          buttonLabel: 'Перейти ко входу',
          onPressed: _openProfile,
        );
      case RequestHistoryViewStatus.empty:
        return _HistoryStateView(
          key: const ValueKey('request-history-empty'),
          icon: Icons.inbox_outlined,
          title: 'Пока нет заявок',
          description:
              'Когда вы отправите заявку из приложения, она появится на этом экране.',
          buttonLabel: 'Обновить',
          onPressed: _reload,
        );
      case RequestHistoryViewStatus.error:
        return _HistoryStateView(
          key: const ValueKey('request-history-error'),
          icon: Icons.cloud_off_rounded,
          title: 'Не удалось загрузить историю',
          description: _controller.errorMessage ??
              'Проверьте интернет и попробуйте снова.',
          buttonLabel: 'Повторить',
          onPressed: _reload,
        );
      case RequestHistoryViewStatus.loaded:
        final filtered = _activeFilter == null
            ? _controller.items
            : _controller.items
                .where((i) => i.type == _activeFilter)
                .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterRail(
              active: _activeFilter,
              onSelected: (t) => setState(() => _activeFilter = t),
            ),
            const SizedBox(height: StarKidsSpacing.md),
            Expanded(
              child: ListView.separated(
                key: ValueKey(
                  'request-history-${_activeFilter?.apiValue ?? 'all'}-${filtered.length}',
                ),
                itemCount: filtered.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: StarKidsSpacing.md),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _HistoryHeader(total: filtered.length);
                  }
                  final item = filtered[index - 1];
                  return StarKidsReveal(
                    delay: starKidsStaggerDelay(index - 1),
                    child: _RequestHistoryCard(item: item),
                  );
                },
              ),
            ),
          ],
        );
    }
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return SolidCard(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      radius: SKRadius.lg,
      child: Text(
        total == 1 ? 'Найдена 1 заявка.' : 'Найдено $total заявок.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

class _RequestHistoryCard extends StatelessWidget {
  const _RequestHistoryCard({required this.item});

  final RequestHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;
    final createdAtLabel = _formatCreatedAt(context, item.createdAt);
    final details = _buildDetails(context, item);

    return SolidCard(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      radius: SKRadius.xl,
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
                        color: c.textSecondary,
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
      rows.add(_HistoryFactRow(label: 'Гостей', value: '${item.guestCount}'));
    }

    if (item.branch != null) {
      rows.add(_HistoryFactRow(label: 'Филиал', value: item.branch!.name));
    }

    if (item.package != null) {
      rows.add(_HistoryFactRow(label: 'Пакет', value: item.package!.name));
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
  const _HistoryFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.labelMedium?.copyWith(color: c.textSecondary),
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
  const _HistoryStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.md,
        vertical: StarKidsSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(SKRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: c.accent,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _HistoryStateView extends StatelessWidget {
  const _HistoryStateView({
    super.key,
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
    final c = SKTheme.of(context).colors;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SolidCard(
          padding: const EdgeInsets.all(StarKidsSpacing.xl),
          radius: SKRadius.xl,
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
                Icon(icon, size: 36, color: c.accent),
              const SizedBox(height: StarKidsSpacing.lg),
              Text(
                title,
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: StarKidsSpacing.sm),
              Text(
                description,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (buttonLabel != null && onPressed != null) ...[
                const SizedBox(height: StarKidsSpacing.lg),
                PrimaryButton(
                  label: buttonLabel!,
                  onPressed: isLoading ? null : onPressed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter chip rail ─────────────────────────────────────────────────────────

class _FilterRail extends StatelessWidget {
  const _FilterRail({required this.active, required this.onSelected});

  final RequestType? active;
  final ValueChanged<RequestType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final textTheme = Theme.of(context).textTheme;

    Widget chip(String label, RequestType? type) {
      final isActive = active == type;
      return GestureDetector(
        onTap: () => onSelected(isActive ? null : type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: StarKidsSpacing.md,
            vertical: StarKidsSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isActive ? c.cta : c.elevated,
            borderRadius: BorderRadius.circular(SKRadius.pill),
            border: Border.all(color: isActive ? c.cta : c.hairline),
          ),
          child: Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: isActive ? Colors.white : c.textSecondary,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Все', null),
          const SizedBox(width: StarKidsSpacing.sm),
          chip(RequestType.birthdayRequest.label, RequestType.birthdayRequest),
          const SizedBox(width: StarKidsSpacing.sm),
          chip(RequestType.contact.label, RequestType.contact),
        ],
      ),
    );
  }
}
