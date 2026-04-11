import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_icon_sizes.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_select_field.dart';
import '../../../branches/domain/branch_option.dart';

Future<void> showTicketPurchaseFlowSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _TicketPurchaseFlowSheet(),
  );
}

Future<void> showMyTicketsPlaceholderSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: StarKidsColors.surfacePrimary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const _MyTicketsPlaceholderSheet(),
  );
}

enum _TicketPurchaseStep {
  selectEntry,
  chooseTickets,
}

class _TicketPurchaseFlowSheet extends StatefulWidget {
  const _TicketPurchaseFlowSheet();

  @override
  State<_TicketPurchaseFlowSheet> createState() =>
      _TicketPurchaseFlowSheetState();
}

class _TicketPurchaseFlowSheetState extends State<_TicketPurchaseFlowSheet> {
  static const _ticketTypes = <_TicketTypeConfig>[
    _TicketTypeConfig(
      id: 'kids_1_3',
      title: 'Детские билеты 1–3 лет',
      priceInTenge: 2700,
      helperText: 'Документ обязателен',
    ),
    _TicketTypeConfig(
      id: 'kids_4_15',
      title: 'Детские билеты 4–15 лет',
      priceInTenge: 3700,
    ),
    _TicketTypeConfig(
      id: 'adult',
      title: 'Взрослый билет (сопровождающий)',
      priceInTenge: 400,
    ),
  ];

  late BranchOption _selectedBranch =
      ServiceRegistry.selectedBranchController.selectedBranch;
  DateTime? _selectedDate;
  var _currentStep = _TicketPurchaseStep.selectEntry;
  var _showPaymentPlaceholder = false;

  final Map<String, int> _ticketCounts = {
    for (final ticketType in _ticketTypes) ticketType.id: 0,
  };

  int get _totalAmount {
    var total = 0;
    for (final ticketType in _ticketTypes) {
      total += (_ticketCounts[ticketType.id] ?? 0) * ticketType.priceInTenge;
    }
    return total;
  }

  int get _totalTickets {
    return _ticketCounts.values.fold<int>(0, (sum, count) => sum + count);
  }

  Future<void> _selectBranch() async {
    List<BranchOption> branches;
    try {
      branches = await ServiceRegistry.branchRepository.listBranches();
    } catch (_) {
      branches = <BranchOption>[_selectedBranch];
    }

    if (!mounted) {
      return;
    }

    final selectedBranch = await showModalBottomSheet<BranchOption>(
      context: context,
      backgroundColor: StarKidsColors.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SelectionSheet<BranchOption>(
        title: 'Выберите филиал',
        items: _deduplicateBranches(branches),
        currentId: _selectedBranch.id,
        itemIdBuilder: (branch) => branch.id,
        titleBuilder: (branch) => branch.name,
        subtitleBuilder: (branch) => branch.address,
      ),
    );

    if (!mounted || selectedBranch == null) {
      return;
    }

    setState(() {
      _selectedBranch = selectedBranch;
    });
  }

  Future<void> _selectDay() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, now.day);
    final availableDays = List<DateTime>.generate(
      21,
      (index) => firstDay.add(Duration(days: index)),
    );

    final selectedDate = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: StarKidsColors.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SelectionSheet<DateTime>(
        title: 'Выберите день',
        items: availableDays,
        currentId: _selectedDate == null ? null : _dateKey(_selectedDate!),
        itemIdBuilder: _dateKey,
        titleBuilder: _formatTicketDate,
        subtitleBuilder: (_) => 'Доступно для покупки входных билетов',
      ),
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = selectedDate;
    });
  }

  void _goToNextStep() {
    if (_selectedDate == null) {
      return;
    }

    setState(() {
      _currentStep = _TicketPurchaseStep.chooseTickets;
      _showPaymentPlaceholder = false;
    });
  }

  void _goBackToSelection() {
    setState(() {
      _currentStep = _TicketPurchaseStep.selectEntry;
      _showPaymentPlaceholder = false;
    });
  }

  void _changeTicketCount(String ticketTypeId, int delta) {
    final currentCount = _ticketCounts[ticketTypeId] ?? 0;
    final nextCount = currentCount + delta;
    if (nextCount < 0) {
      return;
    }

    setState(() {
      _ticketCounts[ticketTypeId] = nextCount;
      _showPaymentPlaceholder = false;
    });
  }

  void _showPaymentStagePlaceholder() {
    if (_totalAmount <= 0) {
      return;
    }

    setState(() {
      _showPaymentPlaceholder = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: StarKidsColors.surfaceCanvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: StarKidsSpacing.md),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: StarKidsColors.borderDefault,
                  borderRadius: BorderRadius.circular(StarKidsRadii.full),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  StarKidsSpacing.md,
                  StarKidsSpacing.md,
                  StarKidsSpacing.md,
                  StarKidsSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (_currentStep == _TicketPurchaseStep.chooseTickets)
                      IconButton(
                        onPressed: _goBackToSelection,
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Назад',
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _currentStep == _TicketPurchaseStep.selectEntry
                                ? 'Купить входной билет'
                                : 'Проверьте состав билетов',
                            style: textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: StarKidsSpacing.xs),
                          Text(
                            _currentStep == _TicketPurchaseStep.selectEntry
                                ? 'Шаг 1 из 2'
                                : 'Шаг 2 из 2',
                            style: textTheme.bodySmall?.copyWith(
                              color: StarKidsColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Закрыть',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _currentStep == _TicketPurchaseStep.selectEntry
                      ? _StepSelectionView(
                          key: const ValueKey('ticket-step-selection'),
                          selectedBranch: _selectedBranch,
                          selectedDate: _selectedDate,
                          onSelectBranch: _selectBranch,
                          onSelectDay: _selectDay,
                        )
                      : _StepTicketsView(
                          key: const ValueKey('ticket-step-details'),
                          selectedBranch: _selectedBranch,
                          selectedDate: _selectedDate!,
                          ticketTypes: _ticketTypes,
                          ticketCounts: _ticketCounts,
                          onDecrease: (ticketTypeId) =>
                              _changeTicketCount(ticketTypeId, -1),
                          onIncrease: (ticketTypeId) =>
                              _changeTicketCount(ticketTypeId, 1),
                        ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  StarKidsSpacing.xl,
                  StarKidsSpacing.md,
                  StarKidsSpacing.xl,
                  StarKidsSpacing.xl + bottomInset,
                ),
                decoration: const BoxDecoration(
                  color: StarKidsColors.surfacePrimary,
                  border: Border(
                    top: BorderSide(color: StarKidsColors.borderDefault),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentStep == _TicketPurchaseStep.chooseTickets) ...[
                      Row(
                        children: [
                          Text('Итого', style: textTheme.titleMedium),
                          const Spacer(),
                          Text(
                            _formatTenge(_totalAmount),
                            style: textTheme.titleMedium?.copyWith(
                              color: StarKidsColors.brandPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: StarKidsSpacing.xs),
                      Text(
                        _totalTickets == 0
                            ? 'Выберите хотя бы один платный билет.'
                            : 'Выбрано билетов: $_totalTickets',
                        style: textTheme.bodySmall?.copyWith(
                          color: StarKidsColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: StarKidsSpacing.md),
                    ],
                    StarKidsButton.primary(
                      label: _currentStep == _TicketPurchaseStep.selectEntry
                          ? 'Продолжить'
                          : 'Оплатить',
                      onPressed: _currentStep == _TicketPurchaseStep.selectEntry
                          ? (_selectedDate == null ? null : _goToNextStep)
                          : (_totalAmount == 0
                                ? null
                                : _showPaymentStagePlaceholder),
                    ),
                    if (_currentStep == _TicketPurchaseStep.chooseTickets &&
                        _showPaymentPlaceholder) ...[
                      const SizedBox(height: StarKidsSpacing.md),
                      Text(
                        'Оплата будет подключена на следующем этапе.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: StarKidsColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<BranchOption> _deduplicateBranches(List<BranchOption> branches) {
    final uniqueById = <String, BranchOption>{};
    uniqueById[_selectedBranch.id] = _selectedBranch;
    for (final branch in branches) {
      uniqueById[branch.id] = branch;
    }
    return uniqueById.values.toList();
  }
}

class _StepSelectionView extends StatelessWidget {
  const _StepSelectionView({
    super.key,
    required this.selectedBranch,
    required this.selectedDate,
    required this.onSelectBranch,
    required this.onSelectDay,
  });

  final BranchOption selectedBranch;
  final DateTime? selectedDate;
  final VoidCallback onSelectBranch;
  final VoidCallback onSelectDay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        StarKidsSpacing.xl,
        StarKidsSpacing.sm,
        StarKidsSpacing.xl,
        StarKidsSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сначала выберите филиал и день посещения. Мы не создаем оплату и бронь автоматически на этом этапе.',
            style: textTheme.bodyMedium?.copyWith(
              color: StarKidsColors.textSecondary,
            ),
          ),
          const SizedBox(height: StarKidsSpacing.xl),
          StarKidsSelectField(
            key: const ValueKey('ticket-branch-select'),
            label: 'Филиал',
            value: selectedBranch.name,
            helperText: selectedBranch.address,
            leadingIcon: Icons.location_on_rounded,
            onTap: onSelectBranch,
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          StarKidsSelectField(
            key: const ValueKey('ticket-day-select'),
            label: 'День',
            value: selectedDate == null ? null : _formatTicketDate(selectedDate!),
            helperText: 'Выберите дату посещения заранее.',
            leadingIcon: Icons.calendar_today_rounded,
            placeholderText: 'Выберите день посещения',
            onTap: onSelectDay,
          ),
        ],
      ),
    );
  }
}

class _StepTicketsView extends StatelessWidget {
  const _StepTicketsView({
    super.key,
    required this.selectedBranch,
    required this.selectedDate,
    required this.ticketTypes,
    required this.ticketCounts,
    required this.onDecrease,
    required this.onIncrease,
  });

  final BranchOption selectedBranch;
  final DateTime selectedDate;
  final List<_TicketTypeConfig> ticketTypes;
  final Map<String, int> ticketCounts;
  final ValueChanged<String> onDecrease;
  final ValueChanged<String> onIncrease;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        StarKidsSpacing.xl,
        StarKidsSpacing.sm,
        StarKidsSpacing.xl,
        StarKidsSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
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
                Text('Выбранный филиал', style: textTheme.labelMedium),
                const SizedBox(height: StarKidsSpacing.xs),
                Text(selectedBranch.name, style: textTheme.titleMedium),
                const SizedBox(height: StarKidsSpacing.sm),
                Text(
                  _formatTicketDate(selectedDate),
                  style: textTheme.bodyMedium?.copyWith(
                    color: StarKidsColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: StarKidsSpacing.xl),
          Text('Количество билетов', style: textTheme.titleLarge),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(
            'Изменяйте количество по каждому типу отдельно. Значение не может уйти ниже нуля.',
            style: textTheme.bodyMedium?.copyWith(
              color: StarKidsColors.textSecondary,
            ),
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          ...ticketTypes.map(
            (ticketType) => Padding(
              padding: const EdgeInsets.only(bottom: StarKidsSpacing.md),
              child: _TicketCounterCard(
                config: ticketType,
                count: ticketCounts[ticketType.id] ?? 0,
                onDecrease: () => onDecrease(ticketType.id),
                onIncrease: () => onIncrease(ticketType.id),
              ),
            ),
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(StarKidsSpacing.lg),
            decoration: BoxDecoration(
              color: StarKidsColors.surfacePrimary,
              borderRadius: BorderRadius.circular(StarKidsRadii.xl),
              border: Border.all(color: StarKidsColors.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Важно знать', style: textTheme.titleMedium),
                const SizedBox(height: StarKidsSpacing.md),
                const _BenefitLine(label: 'Детям 0–1 лет — бесплатно'),
                const SizedBox(height: StarKidsSpacing.sm),
                const _BenefitLine(label: 'Имениннику в день рождения — бесплатно'),
                const SizedBox(height: StarKidsSpacing.sm),
                const _BenefitLine(label: 'Особенным детям — бесплатно'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCounterCard extends StatelessWidget {
  const _TicketCounterCard({
    required this.config,
    required this.count,
    required this.onDecrease,
    required this.onIncrease,
  });

  final _TicketTypeConfig config;
  final int count;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(color: StarKidsColors.borderDefault),
        boxShadow: StarKidsShadows.depth1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config.title, style: textTheme.titleMedium),
                const SizedBox(height: StarKidsSpacing.xs),
                Text(
                  _formatTenge(config.priceInTenge),
                  style: textTheme.bodyLarge?.copyWith(
                    color: StarKidsColors.brandPrimary,
                  ),
                ),
                if (config.helperText != null) ...[
                  const SizedBox(height: StarKidsSpacing.sm),
                  Text(
                    config.helperText!,
                    style: textTheme.bodySmall?.copyWith(
                      color: StarKidsColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: StarKidsSpacing.md),
          _TicketCounterControl(
            ticketTypeId: config.id,
            count: count,
            onDecrease: onDecrease,
            onIncrease: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _TicketCounterControl extends StatelessWidget {
  const _TicketCounterControl({
    required this.ticketTypeId,
    required this.count,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String ticketTypeId;
  final int count;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final canDecrease = count > 0;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: StarKidsColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
        border: Border.all(color: StarKidsColors.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CounterButton(
            key: ValueKey('ticket-decrease-$ticketTypeId'),
            icon: Icons.remove_rounded,
            enabled: canDecrease,
            onTap: onDecrease,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$count',
              key: ValueKey('ticket-count-$ticketTypeId'),
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
          ),
          _CounterButton(
            key: ValueKey('ticket-increase-$ticketTypeId'),
            icon: Icons.add_rounded,
            enabled: true,
            onTap: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: StarKidsIconSizes.sm),
      color: enabled
          ? StarKidsColors.textPrimary
          : StarKidsColors.actionDisabledFg,
      disabledColor: StarKidsColors.actionDisabledFg,
      splashRadius: 20,
      tooltip: null,
    );
  }
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle_rounded,
            size: StarKidsIconSizes.sm,
            color: StarKidsColors.brandPrimary,
          ),
        ),
        const SizedBox(width: StarKidsSpacing.sm),
        Expanded(
          child: Text(label, style: textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _MyTicketsPlaceholderSheet extends StatelessWidget {
  const _MyTicketsPlaceholderSheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          StarKidsSpacing.xl,
          StarKidsSpacing.md,
          StarKidsSpacing.xl,
          StarKidsSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: StarKidsColors.borderDefault,
                  borderRadius: BorderRadius.circular(StarKidsRadii.full),
                ),
              ),
            ),
            const SizedBox(height: StarKidsSpacing.xl),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: StarKidsColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(StarKidsRadii.lg),
              ),
              child: const Icon(
                Icons.confirmation_num_rounded,
                color: StarKidsColors.brandPrimary,
              ),
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            Text('Ваши билеты появятся здесь', style: textTheme.headlineSmall),
            const SizedBox(height: StarKidsSpacing.sm),
            Text(
              'После подключения покупки и истории заказов в этом разделе будут ваши активные входные билеты.',
              style: textTheme.bodyMedium?.copyWith(
                color: StarKidsColors.textSecondary,
              ),
            ),
            const SizedBox(height: StarKidsSpacing.xl),
            StarKidsButton.secondary(
              label: 'Понятно',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionSheet<T> extends StatelessWidget {
  const _SelectionSheet({
    required this.title,
    required this.items,
    required this.currentId,
    required this.itemIdBuilder,
    required this.titleBuilder,
    required this.subtitleBuilder,
  });

  final String title;
  final List<T> items;
  final String? currentId;
  final String Function(T item) itemIdBuilder;
  final String Function(T item) titleBuilder;
  final String Function(T item) subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          StarKidsSpacing.xl,
          StarKidsSpacing.md,
          StarKidsSpacing.xl,
          StarKidsSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: StarKidsColors.borderDefault,
                  borderRadius: BorderRadius.circular(StarKidsRadii.full),
                ),
              ),
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            Text(title, style: textTheme.headlineSmall),
            const SizedBox(height: StarKidsSpacing.lg),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: StarKidsSpacing.sm),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final itemId = itemIdBuilder(item);
                  final isSelected = itemId == currentId;

                  return Material(
                    color: StarKidsColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                    child: InkWell(
                      key: ValueKey('selection-item-$index'),
                      onTap: () => Navigator.of(context).pop(item),
                      borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                      child: Container(
                        padding: const EdgeInsets.all(StarKidsSpacing.lg),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(StarKidsRadii.xl),
                          border: Border.all(
                            color: isSelected
                                ? StarKidsColors.brandPrimary
                                : StarKidsColors.borderDefault,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleBuilder(item),
                                    style: textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: StarKidsSpacing.xs),
                                  Text(
                                    subtitleBuilder(item),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: StarKidsColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: StarKidsSpacing.sm),
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.chevron_right_rounded,
                              color: isSelected
                                  ? StarKidsColors.brandPrimary
                                  : StarKidsColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketTypeConfig {
  const _TicketTypeConfig({
    required this.id,
    required this.title,
    required this.priceInTenge,
    this.helperText,
  });

  final String id;
  final String title;
  final int priceInTenge;
  final String? helperText;
}

String _formatTicketDate(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final weekday = _weekdaysRu[normalized.weekday - 1];
  final month = _monthsRu[normalized.month - 1];
  return '$weekday, ${normalized.day} $month';
}

String _dateKey(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return '${normalized.year}-${normalized.month}-${normalized.day}';
}

String _formatTenge(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index += 1) {
    final reverseIndex = digits.length - index;
    buffer.write(digits[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(' ');
    }
  }

  return '${buffer.toString()} тг';
}

const _weekdaysRu = <String>[
  'Пн',
  'Вт',
  'Ср',
  'Чт',
  'Пт',
  'Сб',
  'Вс',
];

const _monthsRu = <String>[
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];
