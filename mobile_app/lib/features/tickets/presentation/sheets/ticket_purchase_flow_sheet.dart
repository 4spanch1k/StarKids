import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_icon_sizes.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_select_field.dart';
import '../../../../core/utils/result.dart';
import '../../../branches/domain/branch_option.dart';
import '../../domain/branch_ticket_config.dart';
import '../../domain/ticket_purchase.dart';

Future<void> showTicketPurchaseFlowSheet(BuildContext context) {
  return showStarKidsModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _TicketPurchaseFlowSheet(),
  );
}

Future<void> showMyTicketsSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showStarKidsModalBottomSheet<void>(
    context: context,
    backgroundColor: isDark
        ? StarKidsDarkColors.surfaceElevated
        : StarKidsColors.surfacePrimary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const _MyTicketsSheet(),
  );
}

Future<void> showMyTicketsPlaceholderSheet(BuildContext context) {
  return showMyTicketsSheet(context);
}

enum _TicketPurchaseStep { selectEntry, chooseTickets }

enum _TicketPaymentPhase { idle, starting, opened, checking, paid, failed }

class _TicketPurchaseFlowSheet extends StatefulWidget {
  const _TicketPurchaseFlowSheet();

  @override
  State<_TicketPurchaseFlowSheet> createState() =>
      _TicketPurchaseFlowSheetState();
}

class _TicketPurchaseFlowSheetState extends State<_TicketPurchaseFlowSheet> {
  late BranchOption _selectedBranch =
      ServiceRegistry.selectedBranchController.selectedBranch;
  DateTime? _selectedDate;
  var _currentStep = _TicketPurchaseStep.selectEntry;
  var _paymentPhase = _TicketPaymentPhase.idle;
  var _isConfigLoading = true;
  BranchTicketConfig? _ticketConfig;
  String? _configErrorMessage;
  String? _paymentMessage;
  TicketPaymentStart? _activePayment;
  Map<String, int> _ticketCounts = <String, int>{};

  List<TicketConfigItem> get _ticketItems => _ticketConfig?.items ?? const [];

  int get _totalAmount {
    var total = 0;
    for (final ticketType in _ticketItems) {
      total += (_ticketCounts[ticketType.id] ?? 0) * ticketType.priceTenge;
    }
    return total;
  }

  int get _totalTickets {
    return _ticketCounts.values.fold<int>(0, (sum, count) => sum + count);
  }

  bool get _hasAvailableTickets => _ticketItems.isNotEmpty;

  bool get _isPaymentBusy =>
      _paymentPhase == _TicketPaymentPhase.starting ||
      _paymentPhase == _TicketPaymentPhase.checking;

  List<TicketPaymentLineItemPayload> get _selectedPaymentItems {
    return _ticketCounts.entries
        .where((entry) => entry.value > 0)
        .map(
          (entry) => TicketPaymentLineItemPayload(
            ticketItemId: entry.key,
            quantity: entry.value,
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadTicketConfig();
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

    final selectedBranch = await showStarKidsModalBottomSheet<BranchOption>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? StarKidsDarkColors.surfaceElevated
          : StarKidsColors.surfacePrimary,
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

    await _loadTicketConfig();
  }

  Future<void> _selectDay() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, now.day);
    final availableDays = List<DateTime>.generate(
      21,
      (index) => firstDay.add(Duration(days: index)),
    );

    final selectedDate = await showStarKidsModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? StarKidsDarkColors.surfaceElevated
          : StarKidsColors.surfacePrimary,
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
    if (_selectedDate == null ||
        _isConfigLoading ||
        _configErrorMessage != null ||
        !_hasAvailableTickets) {
      return;
    }

    setState(() {
      _currentStep = _TicketPurchaseStep.chooseTickets;
      _resetPaymentState();
    });
  }

  void _goBackToSelection() {
    if (_isPaymentBusy) {
      return;
    }
    setState(() {
      _currentStep = _TicketPurchaseStep.selectEntry;
      _resetPaymentState();
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
      _resetPaymentState();
    });
  }

  Future<void> _startPayment() async {
    if (_totalAmount <= 0) {
      return;
    }
    if (_isPaymentBusy) {
      return;
    }

    setState(() {
      _paymentPhase = _TicketPaymentPhase.starting;
      _paymentMessage = null;
      _activePayment = null;
    });

    final result =
        await ServiceRegistry.ticketPurchaseRepository.startFreedomPayment(
      items: _selectedPaymentItems,
      visitDate: _selectedDate,
    );

    if (!mounted) {
      return;
    }

    if (result is Failure<TicketPaymentStart>) {
      setState(() {
        _paymentPhase = _TicketPaymentPhase.failed;
        _paymentMessage = result.message;
      });
      return;
    }

    final payment = (result as Success<TicketPaymentStart>).data;
    final didOpenPayment = await ServiceRegistry.paymentUrlLauncher(
      payment.paymentUrl,
    );

    if (!mounted) {
      return;
    }

    if (!didOpenPayment) {
      setState(() {
        _paymentPhase = _TicketPaymentPhase.failed;
        _paymentMessage = 'Не удалось открыть страницу Freedom Pay.';
        _activePayment = payment;
      });
      return;
    }

    setState(() {
      _paymentPhase = _TicketPaymentPhase.opened;
      _paymentMessage =
          'Страница оплаты открыта. После завершения вернитесь и проверьте статус.';
      _activePayment = payment;
    });
  }

  Future<void> _checkPaymentStatus() async {
    final payment = _activePayment;
    if (payment == null || _isPaymentBusy) {
      return;
    }

    setState(() {
      _paymentPhase = _TicketPaymentPhase.checking;
      _paymentMessage = 'Проверяем подтверждение от сервера.';
    });

    final result = await ServiceRegistry.ticketPurchaseRepository
        .getPaymentStatus(payment.paymentId);

    if (!mounted) {
      return;
    }

    if (result is Failure<TicketPaymentStatus>) {
      setState(() {
        _paymentPhase = _TicketPaymentPhase.opened;
        _paymentMessage = result.message;
      });
      return;
    }

    final paymentStatus = (result as Success<TicketPaymentStatus>).data;
    setState(() {
      switch (paymentStatus.status) {
        case TicketPaymentStatusValue.paid:
          _paymentPhase = _TicketPaymentPhase.paid;
          _paymentMessage =
              'Оплата подтверждена сервером. Билет добавлен в «Мои билеты».';
          break;
        case TicketPaymentStatusValue.failed:
        case TicketPaymentStatusValue.canceled:
        case TicketPaymentStatusValue.expired:
          _paymentPhase = _TicketPaymentPhase.failed;
          _paymentMessage = paymentStatus.failureReason ??
              'Оплата не прошла. Можно попробовать еще раз.';
          break;
        case TicketPaymentStatusValue.created:
        case TicketPaymentStatusValue.pending:
        case TicketPaymentStatusValue.unknown:
          _paymentPhase = _TicketPaymentPhase.opened;
          _paymentMessage =
              'Платеж еще обрабатывается. Повторите проверку чуть позже.';
          break;
      }
    });
  }

  Future<void> _loadTicketConfig() async {
    setState(() {
      _isConfigLoading = true;
      _configErrorMessage = null;
      _resetPaymentState();
    });

    try {
      final config = await ServiceRegistry.ticketConfigRepository.getForBranch(
        _selectedBranch.id,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _ticketConfig = config;
        _ticketCounts = {
          for (final item in config.items) item.id: _ticketCounts[item.id] ?? 0,
        };
        _isConfigLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _ticketConfig = null;
        _ticketCounts = <String, int>{};
        _isConfigLoading = false;
        _configErrorMessage =
            'Не удалось загрузить конфигурацию билетов для выбранного филиала.';
      });
    }
  }

  void _resetPaymentState() {
    _paymentPhase = _TicketPaymentPhase.idle;
    _paymentMessage = null;
    _activePayment = null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FractionallySizedBox(
      heightFactor: 0.98,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark
              ? StarKidsDarkColors.surfaceCanvas
              : StarKidsColors.surfaceCanvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                  color: isDark
                      ? StarKidsDarkColors.borderDefault
                      : StarKidsColors.borderDefault,
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
                        onPressed: _isPaymentBusy ? null : _goBackToSelection,
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
                              color: isDark
                                  ? StarKidsDarkColors.textSecondary
                                  : StarKidsColors.textSecondary,
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
                child: StarKidsContentSwitcher(
                  child: _currentStep == _TicketPurchaseStep.selectEntry
                      ? _StepSelectionView(
                          key: const ValueKey('ticket-step-selection'),
                          selectedBranch: _selectedBranch,
                          selectedDate: _selectedDate,
                          ticketConfig: _ticketConfig,
                          isConfigLoading: _isConfigLoading,
                          configErrorMessage: _configErrorMessage,
                          onSelectBranch: _selectBranch,
                          onSelectDay: _selectDay,
                        )
                      : _StepTicketsView(
                          key: const ValueKey('ticket-step-details'),
                          selectedBranch: _selectedBranch,
                          selectedDate: _selectedDate!,
                          ticketConfig: _ticketConfig,
                          isConfigLoading: _isConfigLoading,
                          configErrorMessage: _configErrorMessage,
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
                decoration: BoxDecoration(
                  color: isDark
                      ? StarKidsDarkColors.surfacePrimary
                      : StarKidsColors.surfacePrimary,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? StarKidsDarkColors.borderDefault
                          : StarKidsColors.borderDefault,
                    ),
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
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.48,
                              color: isDark
                                  ? StarKidsDarkColors.textPrimary
                                  : StarKidsColors.textPrimary,
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
                          color: isDark
                              ? StarKidsDarkColors.textSecondary
                              : StarKidsColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: StarKidsSpacing.md),
                    ],
                    StarKidsButton.primary(
                      label: _primaryActionLabel,
                      onPressed: _currentStep == _TicketPurchaseStep.selectEntry
                          ? (_selectedDate == null ||
                                  _isConfigLoading ||
                                  _configErrorMessage != null ||
                                  !_hasAvailableTickets
                              ? null
                              : _goToNextStep)
                          : (_totalAmount == 0 ||
                                  _isPaymentBusy ||
                                  _paymentPhase == _TicketPaymentPhase.paid
                              ? null
                              : _startPayment),
                      isLoading: _paymentPhase == _TicketPaymentPhase.starting,
                    ),
                    if (_currentStep == _TicketPurchaseStep.chooseTickets &&
                        _activePayment != null &&
                        _paymentPhase != _TicketPaymentPhase.paid) ...[
                      const SizedBox(height: StarKidsSpacing.sm),
                      StarKidsButton.secondary(
                        label: _paymentPhase == _TicketPaymentPhase.checking
                            ? 'Проверяем статус'
                            : 'Проверить оплату',
                        onPressed: _isPaymentBusy ? null : _checkPaymentStatus,
                        isLoading:
                            _paymentPhase == _TicketPaymentPhase.checking,
                      ),
                    ],
                    if (_currentStep == _TicketPurchaseStep.chooseTickets &&
                        _paymentMessage != null) ...[
                      const SizedBox(height: StarKidsSpacing.md),
                      Text(
                        _paymentMessage!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: _paymentPhase == _TicketPaymentPhase.failed
                              ? (isDark
                                  ? StarKidsDarkColors.statusError
                                  : StarKidsColors.statusError)
                              : (isDark
                                  ? StarKidsDarkColors.textSecondary
                                  : StarKidsColors.textSecondary),
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

  String get _primaryActionLabel {
    if (_currentStep == _TicketPurchaseStep.selectEntry) {
      return 'Продолжить';
    }
    return switch (_paymentPhase) {
      _TicketPaymentPhase.starting => 'Готовим оплату',
      _TicketPaymentPhase.paid => 'Оплата подтверждена',
      _ => 'Оплатить через Freedom Pay',
    };
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
    required this.ticketConfig,
    required this.isConfigLoading,
    required this.configErrorMessage,
    required this.onSelectBranch,
    required this.onSelectDay,
  });

  final BranchOption selectedBranch;
  final DateTime? selectedDate;
  final BranchTicketConfig? ticketConfig;
  final bool isConfigLoading;
  final String? configErrorMessage;
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
            value:
                selectedDate == null ? null : _formatTicketDate(selectedDate!),
            helperText: 'Выберите дату посещения заранее.',
            leadingIcon: Icons.calendar_today_rounded,
            placeholderText: 'Выберите день посещения',
            onTap: onSelectDay,
          ),
          const SizedBox(height: StarKidsSpacing.xl),
          Text('Доступные билеты', style: textTheme.titleLarge),
          const SizedBox(height: StarKidsSpacing.sm),
          if (isConfigLoading)
            const _TicketConfigStateCard(
              title: 'Загружаем билеты',
              description:
                  'Подтягиваем билетную конфигурацию выбранного филиала.',
            )
          else if (configErrorMessage != null)
            _TicketConfigStateCard(
              title: 'Не удалось загрузить конфигурацию',
              description: configErrorMessage!,
            )
          else if (ticketConfig == null || ticketConfig!.items.isEmpty)
            const _TicketConfigStateCard(
              title: 'Билеты пока недоступны',
              description:
                  'Для выбранного филиала пока нет активных билетов в конфигурации.',
            )
          else
            _TicketConfigPreviewCard(config: ticketConfig!),
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
    required this.ticketConfig,
    required this.isConfigLoading,
    required this.configErrorMessage,
    required this.ticketCounts,
    required this.onDecrease,
    required this.onIncrease,
  });

  final BranchOption selectedBranch;
  final DateTime selectedDate;
  final BranchTicketConfig? ticketConfig;
  final bool isConfigLoading;
  final String? configErrorMessage;
  final Map<String, int> ticketCounts;
  final ValueChanged<String> onDecrease;
  final ValueChanged<String> onIncrease;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? StarKidsDarkColors.surfacePrimary
        : StarKidsColors.surfacePrimary;
    final borderColor = isDark
        ? StarKidsDarkColors.borderDefault
        : StarKidsColors.borderDefault;
    final secondaryText = isDark
        ? StarKidsDarkColors.textSecondary
        : StarKidsColors.textSecondary;

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
              color: cardBg,
              borderRadius: BorderRadius.circular(StarKidsRadii.xl),
              border: Border.all(color: borderColor),
              boxShadow: isDark ? null : StarKidsShadows.depth1,
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
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: StarKidsSpacing.xl),
          Text('Количество билетов', style: textTheme.titleLarge),
          const SizedBox(height: StarKidsSpacing.lg),
          if (isConfigLoading)
            const _TicketConfigStateCard(
              title: 'Загружаем билеты',
              description:
                  'Подтягиваем билетную конфигурацию выбранного филиала.',
            )
          else if (configErrorMessage != null)
            _TicketConfigStateCard(
              title: 'Не удалось загрузить конфигурацию',
              description: configErrorMessage!,
            )
          else if (ticketConfig == null || ticketConfig!.items.isEmpty)
            const _TicketConfigStateCard(
              title: 'Билеты пока недоступны',
              description:
                  'Для этого филиала пока нет активных билетов.',
            )
          else
            ...ticketConfig!.items.map(
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
          if ((ticketConfig?.notes ?? const <String>[]).isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(StarKidsSpacing.lg),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Важно знать', style: textTheme.titleMedium),
                  const SizedBox(height: StarKidsSpacing.md),
                  for (var index = 0;
                      index < ticketConfig!.notes.length;
                      index++) ...[
                    _BenefitLine(label: ticketConfig!.notes[index]),
                    if (index < ticketConfig!.notes.length - 1)
                      const SizedBox(height: StarKidsSpacing.sm),
                  ],
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

  final TicketConfigItem config;
  final int count;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? StarKidsDarkColors.surfacePrimary
            : StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(
          color: isDark
              ? StarKidsDarkColors.borderDefault
              : StarKidsColors.borderDefault,
        ),
        boxShadow: isDark ? null : StarKidsShadows.depth1,
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
                  _formatTenge(config.priceTenge),
                  style: textTheme.bodyLarge?.copyWith(
                    color: isDark
                        ? StarKidsDarkColors.accentPink
                        : StarKidsColors.textPrimary,
                  ),
                ),
                if (config.description.isNotEmpty) ...[
                  const SizedBox(height: StarKidsSpacing.sm),
                  Text(
                    config.description,
                    style: textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? StarKidsDarkColors.textSecondary
                          : StarKidsColors.textSecondary,
                    ),
                  ),
                ],
                if (config.badgeLabels.isNotEmpty) ...[
                  const SizedBox(height: StarKidsSpacing.sm),
                  Wrap(
                    spacing: StarKidsSpacing.xs,
                    runSpacing: StarKidsSpacing.xs,
                    children: config.badgeLabels
                        .map((label) => _TicketBadgeChip(label: label))
                        .toList(),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? StarKidsDarkColors.glassSurface
            : StarKidsColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
        border: Border.all(
          color: isDark
              ? StarKidsDarkColors.borderDefault
              : StarKidsColors.borderDefault,
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: StarKidsIconSizes.sm),
      color: enabled
          ? (isDark ? StarKidsDarkColors.textPrimary : StarKidsColors.textPrimary)
          : (isDark
              ? StarKidsDarkColors.actionDisabledFg
              : StarKidsColors.actionDisabledFg),
      disabledColor: isDark
          ? StarKidsDarkColors.actionDisabledFg
          : StarKidsColors.actionDisabledFg,
      splashRadius: 20,
      tooltip: null,
    );
  }
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({required this.label});

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
        Expanded(child: Text(label, style: textTheme.bodyMedium)),
      ],
    );
  }
}

class _TicketBadgeChip extends StatelessWidget {
  const _TicketBadgeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.sm,
        vertical: StarKidsSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? StarKidsDarkColors.glassSurface
            : StarKidsColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
        border: Border.all(
          color: isDark
              ? StarKidsDarkColors.borderDefault
              : StarKidsColors.borderDefault,
        ),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: isDark
              ? StarKidsDarkColors.textPrimary
              : StarKidsColors.textPrimary,
        ),
      ),
    );
  }
}

class _TicketConfigPreviewCard extends StatelessWidget {
  const _TicketConfigPreviewCard({required this.config});

  final BranchTicketConfig config;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? StarKidsDarkColors.surfacePrimary
            : StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(
          color: isDark
              ? StarKidsDarkColors.borderDefault
              : StarKidsColors.borderDefault,
        ),
        boxShadow: isDark ? null : StarKidsShadows.depth1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < config.items.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.items[index].title,
                        style: textTheme.titleMedium,
                      ),
                      if (config.items[index].description.isNotEmpty) ...[
                        const SizedBox(height: StarKidsSpacing.xs),
                        Text(
                          config.items[index].description,
                          style: textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? StarKidsDarkColors.textSecondary
                                : StarKidsColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: StarKidsSpacing.md),
                Text(
                  _formatTenge(config.items[index].priceTenge),
                  style: textTheme.titleMedium?.copyWith(
                    color: isDark
                        ? StarKidsDarkColors.accentPink
                        : StarKidsColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (config.items[index].badgeLabels.isNotEmpty) ...[
              const SizedBox(height: StarKidsSpacing.xs),
              Wrap(
                spacing: StarKidsSpacing.xs,
                runSpacing: StarKidsSpacing.xs,
                children: config.items[index].badgeLabels
                    .map((label) => _TicketBadgeChip(label: label))
                    .toList(),
              ),
            ],
            if (index < config.items.length - 1) ...[
              const SizedBox(height: StarKidsSpacing.md),
              Divider(
                height: 1,
                color: isDark
                    ? StarKidsDarkColors.borderDefault
                    : StarKidsColors.borderDefault,
              ),
              const SizedBox(height: StarKidsSpacing.md),
            ],
          ],
        ],
      ),
    );
  }
}

class _TicketConfigStateCard extends StatelessWidget {
  const _TicketConfigStateCard({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? StarKidsDarkColors.surfacePrimary
            : StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(
          color: isDark
              ? StarKidsDarkColors.borderDefault
              : StarKidsColors.borderDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: StarKidsSpacing.xs),
          Text(
            description,
            style: textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? StarKidsDarkColors.textSecondary
                  : StarKidsColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyTicketsSheet extends StatefulWidget {
  const _MyTicketsSheet();

  @override
  State<_MyTicketsSheet> createState() => _MyTicketsSheetState();
}

class _MyTicketsSheetState extends State<_MyTicketsSheet> {
  var _isLoading = true;
  String? _errorMessage;
  List<PurchasedTicket> _tickets = const [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result =
        await ServiceRegistry.ticketPurchaseRepository.listPurchasedTickets();
    if (!mounted) {
      return;
    }

    if (result is Failure<List<PurchasedTicket>>) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
        _tickets = const [];
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = null;
      _tickets = (result as Success<List<PurchasedTicket>>).data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  color: isDark
                      ? StarKidsDarkColors.borderDefault
                      : StarKidsColors.borderDefault,
                  borderRadius: BorderRadius.circular(StarKidsRadii.full),
                ),
              ),
            ),
            const SizedBox(height: StarKidsSpacing.xl),
            Text('Мои билеты', style: textTheme.headlineSmall),
            const SizedBox(height: StarKidsSpacing.sm),
            Text(
              'Все подтверждённые билеты в одном месте.',
              style: textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? StarKidsDarkColors.textSecondary
                    : StarKidsColors.textSecondary,
              ),
            ),
            const SizedBox(height: StarKidsSpacing.xl),
            if (_isLoading)
              const _TicketConfigStateCard(
                title: 'Загружаем билеты',
                description: 'Проверяем подтвержденные покупки.',
              )
            else if (_errorMessage != null)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TicketConfigStateCard(
                    title: 'Не удалось загрузить билеты',
                    description: _errorMessage!,
                  ),
                  const SizedBox(height: StarKidsSpacing.md),
                  StarKidsButton.secondary(
                    label: 'Повторить',
                    onPressed: _loadTickets,
                  ),
                ],
              )
            else if (_tickets.isEmpty)
              const _TicketConfigStateCard(
                title: 'Пока нет купленных билетов',
                description:
                    'После подтвержденной оплаты билет появится здесь автоматически.',
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _tickets.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: StarKidsSpacing.md),
                  itemBuilder: (context, index) {
                    return _PurchasedTicketCard(ticket: _tickets[index]);
                  },
                ),
              ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsButton.secondary(
              label: 'Закрыть',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchasedTicketCard extends StatelessWidget {
  const _PurchasedTicketCard({required this.ticket});

  final PurchasedTicket ticket;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? StarKidsDarkColors.surfacePrimary
            : StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(
          color: isDark
              ? StarKidsDarkColors.borderDefault
              : StarKidsColors.borderDefault,
        ),
        boxShadow: isDark ? null : StarKidsShadows.depth1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? StarKidsDarkColors.statusSuccessSurface
                      : StarKidsColors.statusSuccessSurface,
                  borderRadius: BorderRadius.circular(StarKidsRadii.lg),
                ),
                child: Icon(
                  Icons.confirmation_num_rounded,
                  color: isDark
                      ? StarKidsDarkColors.statusSuccess
                      : StarKidsColors.statusSuccess,
                ),
              ),
              const SizedBox(width: StarKidsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ticket.branchName, style: textTheme.titleMedium),
                    const SizedBox(height: StarKidsSpacing.xs),
                    Text(
                      ticket.visitDate == null
                          ? 'Дата посещения не указана'
                          : _formatTicketDate(ticket.visitDate!),
                      style: textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? StarKidsDarkColors.textSecondary
                            : StarKidsColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StarKidsSpacing.sm),
              Text(
                _formatTenge(ticket.amountTenge),
                style: textTheme.titleSmall?.copyWith(
                  color: isDark
                      ? StarKidsDarkColors.accentPink
                      : StarKidsColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: StarKidsSpacing.md),
          for (final item in ticket.items) ...[
            Text(
              '${item.title} x ${item.quantity}',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: StarKidsSpacing.xs),
          ],
          Text(
            'Заказ ${ticket.localOrderId}',
            style: textTheme.bodySmall?.copyWith(
              color: isDark
                  ? StarKidsDarkColors.textSecondary
                  : StarKidsColors.textSecondary,
            ),
          ),
        ],
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  color: isDark
                      ? StarKidsDarkColors.borderDefault
                      : StarKidsColors.borderDefault,
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

                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final accentColor = isDark
                      ? StarKidsDarkColors.accentPink
                      : StarKidsColors.brandPrimary;
                  final secondaryText = isDark
                      ? StarKidsDarkColors.textSecondary
                      : StarKidsColors.textSecondary;
                  return Material(
                    color: isDark
                        ? StarKidsDarkColors.surfacePrimary
                        : StarKidsColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                    child: InkWell(
                      key: ValueKey('selection-item-$index'),
                      onTap: () => Navigator.of(context).pop(item),
                      borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                      child: Container(
                        padding: const EdgeInsets.all(StarKidsSpacing.lg),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                          border: Border.all(
                            color: isSelected
                                ? accentColor
                                : (isDark
                                    ? StarKidsDarkColors.borderDefault
                                    : StarKidsColors.borderDefault),
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
                                      color: secondaryText,
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
                              color: isSelected ? accentColor : secondaryText,
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

const _weekdaysRu = <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

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
