import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/widgets/glass_bottom_sheet.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/utils/result.dart';
import '../../../children/domain/child.dart';
import '../../../children/presentation/controllers/children_controller.dart';
import '../../domain/pass.dart';
import '../../domain/pass_repository.dart';
import '../../../tickets/domain/ticket_purchase.dart';
import '../../../tickets/presentation/controllers/payment_return_coordinator.dart';

Future<bool> showPassPurchaseFlowSheet(
  BuildContext context, {
  PassRepository? repository,
}) async {
  final result = await showGlassBottomSheet<bool>(
    context: context,
    title: 'Купить абонемент',
    initialSize: 0.86,
    builder: (ctx, scroll) => _PassPurchaseFlowSheet(
      repository: repository ?? ServiceRegistry.passRepository,
      scrollController: scroll,
    ),
  );
  return result ?? false;
}

enum _PassPaymentPhase { idle, starting, opened, checking, paid, failed }

class _PassCheckoutSelection {
  const _PassCheckoutSelection({
    required this.childId,
    required this.passPlanId,
    required this.branchId,
  });

  final String childId;
  final String passPlanId;
  final String branchId;
}

class _PassPurchaseFlowSheet extends StatefulWidget {
  const _PassPurchaseFlowSheet({
    required this.repository,
    required this.scrollController,
  });
  final PassRepository repository;
  final ScrollController scrollController;
  @override
  State<_PassPurchaseFlowSheet> createState() => _PassPurchaseFlowSheetState();
}

class _PassPurchaseFlowSheetState extends State<_PassPurchaseFlowSheet> {
  List<PassPlan> _plans = const [];
  List<Child> _children = const [];
  Child? _selectedChild;
  PassPlan? _selectedPlan;
  PassQuote? _quote;
  String? _error;
  String? _paymentMessage;
  String? _childrenError;
  String? _baselineError;
  String? _plansError;
  _PassPaymentPhase _phase = _PassPaymentPhase.idle;
  String? _idempotencyKey;
  String? _selectionKey;
  String? _paymentId;
  String? _paymentUrl;
  _PassCheckoutSelection? _activeCheckoutSelection;
  var _paymentUrlOpenFailed = false;
  StreamSubscription<PaymentReturnEvent>? _subscription;
  var _loading = true;
  var _quoteLoading = false;
  var _plansLoading = false;
  var _baselineReady = false;
  var _quoteRequestVersion = 0;
  final Set<String> _existingPassIds = <String>{};

  bool get _busy =>
      _phase == _PassPaymentPhase.starting ||
      _phase == _PassPaymentPhase.checking;

  bool get _selectionLocked =>
      _activeCheckoutSelection != null && _phase != _PassPaymentPhase.failed;

  @override
  void initState() {
    super.initState();
    ServiceRegistry.paymentReturnCoordinator.attachCheckoutListener();
    _subscription = ServiceRegistry.paymentReturnCoordinator.events.listen(
      _handleReturn,
    );
    _load();
  }

  @override
  void dispose() {
    ServiceRegistry.paymentReturnCoordinator.detachCheckoutListener();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _childrenError = null;
      _baselineError = null;
      _plansError = null;
      _error = null;
    });
    final childrenController = ServiceRegistry.childrenController;
    if (childrenController.status != ChildrenStatus.success &&
        childrenController.status != ChildrenStatus.empty) {
      await childrenController.load();
    }
    if (!mounted) return;
    if (childrenController.status == ChildrenStatus.error) {
      setState(() {
        _loading = false;
        _childrenError = childrenController.errorMessage ??
            'Не удалось загрузить детей. Попробуйте ещё раз.';
      });
      return;
    }
    _children = List<Child>.of(childrenController.children);
    if (_children.isNotEmpty) _selectedChild = _children.first;
    if (_children.isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }
    final existing = await widget.repository.listPasses();
    if (existing is Failure<List<CustomerPass>>) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _baselineReady = false;
        _baselineError = existing.message;
      });
      return;
    }
    _existingPassIds
      ..clear()
      ..addAll(
        (existing as Success<List<CustomerPass>>).data.map((pass) => pass.id),
      );
    _baselineReady = true;
    await _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _plansLoading = true;
      _error = null;
    });
    final branchId = ServiceRegistry.selectedBranchController.selectedBranch.id;
    final result = await widget.repository.listPlans(branchId: branchId);
    if (!mounted) return;
    if (result is Failure<List<PassPlan>>) {
      setState(() {
        _plansLoading = false;
        _loading = false;
        _plansError = result.message;
      });
      return;
    }
    _plans = (result as Success<List<PassPlan>>).data;
    setState(() {
      _plansLoading = false;
      _loading = false;
      _plansError = null;
    });
    if (_plans.isNotEmpty) {
      _selectedPlan = _plans.first;
      _selectionKey =
          '${_selectedChild!.id}:${_selectedPlan!.id}:${ServiceRegistry.selectedBranchController.selectedBranch.id}';
      await _refreshQuote();
    }
  }

  void _updateSelection({Child? child, PassPlan? plan}) {
    if (_selectionLocked) return;
    final nextChild = child ?? _selectedChild;
    final nextPlan = plan ?? _selectedPlan;
    final nextKey = nextChild == null || nextPlan == null
        ? null
        : '${nextChild.id}:${nextPlan.id}:${ServiceRegistry.selectedBranchController.selectedBranch.id}';
    if (nextKey != _selectionKey) {
      _idempotencyKey = null;
      _selectionKey = nextKey;
    }
    _quoteRequestVersion++;
    setState(() {
      _selectedChild = nextChild;
      _selectedPlan = nextPlan;
      _quote = null;
      _phase = _PassPaymentPhase.idle;
      _paymentMessage = null;
    });
    unawaited(_refreshQuote());
  }

  Future<void> _refreshQuote() async {
    final child = _selectedChild;
    final plan = _selectedPlan;
    if (child == null || plan == null) return;
    final requestedChildId = child.id;
    final requestedPlanId = plan.id;
    final requestedBranchId =
        ServiceRegistry.selectedBranchController.selectedBranch.id;
    final requestVersion = ++_quoteRequestVersion;
    setState(() => _quoteLoading = true);
    final result = await widget.repository.quote(
      childId: requestedChildId,
      passPlanId: requestedPlanId,
      branchId: requestedBranchId,
    );
    if (!mounted) return;
    final currentBranchId =
        ServiceRegistry.selectedBranchController.selectedBranch.id;
    if (requestVersion != _quoteRequestVersion ||
        _selectedChild?.id != requestedChildId ||
        _selectedPlan?.id != requestedPlanId ||
        currentBranchId != requestedBranchId) {
      return;
    }
    if (result is Failure<PassQuote>) {
      setState(() {
        _quoteLoading = false;
        _error = result.message;
        _quote = null;
      });
    } else {
      setState(() {
        _quoteLoading = false;
        _error = null;
        _quote = (result as Success<PassQuote>).data;
      });
    }
  }

  Future<void> _startPayment() async {
    final child = _selectedChild;
    final plan = _selectedPlan;
    final quote = _quote;
    final branchId = ServiceRegistry.selectedBranchController.selectedBranch.id;
    if (child == null || plan == null || _busy || !_baselineReady) return;
    final selection = _activeCheckoutSelection ??
        _PassCheckoutSelection(
          childId: child.id,
          passPlanId: plan.id,
          branchId: branchId,
        );
    final currentSelectionMatches = child.id == selection.childId &&
        plan.id == selection.passPlanId &&
        branchId == selection.branchId;
    if (!currentSelectionMatches ||
        quote == null ||
        quote.childId != selection.childId ||
        quote.plan.id != selection.passPlanId ||
        quote.branchId != selection.branchId) {
      setState(() {
        _error = 'Обновляем стоимость для выбранного абонемента…';
      });
      await _refreshQuote();
      return;
    }
    _activeCheckoutSelection = selection;
    _idempotencyKey ??= _newIdempotencyKey();
    setState(() {
      _phase = _PassPaymentPhase.starting;
      _paymentMessage = null;
      _error = null;
      _paymentUrlOpenFailed = false;
    });
    final result = await widget.repository.startPayment(
      childId: selection.childId,
      passPlanId: selection.passPlanId,
      branchId: selection.branchId,
      idempotencyKey: _idempotencyKey!,
    );
    if (!mounted) return;
    if (result is Failure<PassPaymentStart>) {
      setState(() {
        // The request may have reached the backend before the response was
        // lost. Keep the logical checkout and idempotency key for retry.
        _phase = _PassPaymentPhase.idle;
        _paymentId = null;
        _paymentUrl = null;
        _paymentUrlOpenFailed = false;
        _paymentMessage = result.message;
      });
      return;
    }
    final payment = (result as Success<PassPaymentStart>).data;
    _paymentId = payment.paymentId;
    final status = payment.status.trim().toLowerCase();
    if (status == 'paid') {
      await ServiceRegistry.paymentReturnCoordinator.completeRegisteredPayment(
        payment.paymentId,
      );
      await _reconcilePaid();
      return;
    }
    if (status == 'failed' || status == 'canceled' || status == 'expired') {
      await _handleTerminalFailure(
        payment.paymentId,
        'Оплата не прошла. Можно попробовать ещё раз.',
      );
      return;
    }
    if (status != 'pending' || payment.paymentUrl.trim().isEmpty) {
      await _handleTerminalFailure(
        payment.paymentId,
        'Не удалось продолжить оплату. Попробуйте начать заново.',
      );
      return;
    }
    _paymentUrl = payment.paymentUrl;
    await ServiceRegistry.paymentReturnCoordinator.registerPayment(
      payment.paymentId,
      checkoutKind: PaymentCheckoutKind.pass,
    );
    setState(() {
      _phase = _PassPaymentPhase.opened;
      _paymentMessage =
          'Откройте страницу оплаты. После оплаты вернитесь в Boom Bala.';
    });
    await _openPaymentUrl();
  }

  Future<void> _openPaymentUrl() async {
    final paymentUrl = _paymentUrl;
    if (paymentUrl == null || paymentUrl.trim().isEmpty) {
      await _handleTerminalFailure(
        _paymentId ?? '',
        'Не удалось открыть страницу оплаты.',
      );
      return;
    }
    final opened = await ServiceRegistry.paymentUrlLauncher(paymentUrl);
    if (!mounted) return;
    setState(() {
      _phase = _PassPaymentPhase.opened;
      _paymentUrlOpenFailed = !opened;
      _paymentMessage = opened
          ? 'Откройте страницу оплаты. После оплаты вернитесь в Boom Bala.'
          : 'Не удалось открыть страницу оплаты. Повторите попытку.';
    });
  }

  Future<void> _handleTerminalFailure(String paymentId, String message) async {
    if (paymentId.trim().isNotEmpty) {
      await ServiceRegistry.paymentReturnCoordinator
          .completeRegisteredPayment(paymentId);
    }
    if (!mounted) return;
    _paymentId = null;
    _paymentUrl = null;
    _activeCheckoutSelection = null;
    _idempotencyKey = null;
    _paymentUrlOpenFailed = false;
    _quoteRequestVersion++;
    setState(() {
      _phase = _PassPaymentPhase.failed;
      _error = message;
      _paymentMessage = null;
      _quote = null;
    });
    // A terminal provider result ends the logical checkout. The next
    // explicit attempt must use a fresh authoritative quote as well as a new
    // idempotency key.
    unawaited(_refreshQuote());
  }

  Future<void> _handleReturn(PaymentReturnEvent event) async {
    if (!mounted ||
        event.checkoutKind != PaymentCheckoutKind.pass ||
        event.paymentId != _paymentId) return;
    if (event.isPaid) {
      await ServiceRegistry.paymentReturnCoordinator.completeRegisteredPayment(
        event.paymentId,
      );
      await _reconcilePaid();
    } else if (event.status != null && event.status!.isFinal) {
      await _handleTerminalFailure(
        event.paymentId,
        event.errorMessage ??
            event.status!.failureReason ??
            'Оплата не прошла.',
      );
    } else if (mounted) {
      setState(() {
        _phase = _PassPaymentPhase.opened;
        _paymentMessage = event.errorMessage ??
            'Платёж ещё обрабатывается. Проверьте оплату ещё раз.';
      });
    }
  }

  Future<void> _checkPaymentStatus() async {
    final paymentId = _paymentId;
    if (paymentId == null || _busy) return;
    setState(() {
      _phase = _PassPaymentPhase.checking;
      _error = null;
      _paymentMessage = 'Проверяем оплату…';
    });
    final result = await ServiceRegistry.ticketPurchaseRepository
        .getPaymentStatus(paymentId);
    if (!mounted) return;
    if (result is Failure<TicketPaymentStatus>) {
      setState(() {
        _phase = _PassPaymentPhase.opened;
        _paymentMessage = result.message;
      });
      return;
    }
    final status = (result as Success<TicketPaymentStatus>).data;
    if (status.status == TicketPaymentStatusValue.paid) {
      await ServiceRegistry.paymentReturnCoordinator.completeRegisteredPayment(
        paymentId,
      );
      await _reconcilePaid();
      return;
    }
    if (status.isFinal) {
      await _handleTerminalFailure(
        paymentId,
        status.failureReason ?? 'Оплата не прошла.',
      );
      return;
    }
    setState(() {
      _phase = _PassPaymentPhase.opened;
      _paymentMessage =
          'Платёж ещё обрабатывается. Попробуйте проверить ещё раз.';
    });
  }

  Future<void> _reconcilePaid() async {
    final checkoutSelection = _activeCheckoutSelection;
    if (checkoutSelection == null) {
      if (mounted) {
        setState(() {
          _phase = _PassPaymentPhase.failed;
          _error = 'Не удалось определить состав покупки. Попробуйте ещё раз.';
        });
      }
      return;
    }
    setState(() {
      _phase = _PassPaymentPhase.checking;
      _paymentMessage = 'Оплата подтверждена. Выпускаем абонемент…';
    });
    for (var attempt = 0; attempt < 6; attempt++) {
      final result = await widget.repository.listPasses();
      if (result is Success<List<CustomerPass>>) {
        final passes = result.data;
        final found = passes
            .where(
              (pass) =>
                  !_existingPassIds.contains(pass.id) &&
                  pass.childId == checkoutSelection.childId &&
                  pass.passPlanId == checkoutSelection.passPlanId,
            )
            .toList();
        if (found.isNotEmpty) {
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (mounted)
      setState(() {
        _phase = _PassPaymentPhase.paid;
        _paymentMessage =
            'Оплата прошла. Абонемент появится в разделе «Абонементы», как только выпуск завершится.';
      });
  }

  String _newIdempotencyKey() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  @override
  Widget build(BuildContext context) {
    if (_loading || _plansLoading)
      return const Padding(
        padding: EdgeInsets.all(SKSpacing.x6),
        child: Center(child: CircularProgressIndicator()),
      );
    if (_childrenError != null)
      return Padding(
        padding: const EdgeInsets.all(SKSpacing.x5),
        child: _LoadErrorCard(message: _childrenError!, onRetry: _load),
      );
    if (_children.isEmpty)
      return _NoChildren(
        onOpenProfile: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(AppRoutes.profile);
        },
      );
    if (_baselineError != null)
      return Padding(
        padding: const EdgeInsets.all(SKSpacing.x5),
        child: _LoadErrorCard(message: _baselineError!, onRetry: _load),
      );
    if (_plansError != null)
      return Padding(
        padding: const EdgeInsets.all(SKSpacing.x5),
        child: _LoadErrorCard(message: _plansError!, onRetry: _load),
      );
    if (_error != null && _plans.isEmpty)
      return Padding(
        padding: const EdgeInsets.all(SKSpacing.x5),
        child: Text(_error!),
      );
    if (_plans.isEmpty)
      return const Padding(
        padding: EdgeInsets.all(SKSpacing.x5),
        child: Text('Сейчас нет доступных абонементов для выбранного филиала.'),
      );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SKSpacing.x5,
        SKSpacing.x2,
        SKSpacing.x5,
        SKSpacing.x6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Выберите ребёнка',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SKSpacing.x2),
          DropdownButtonFormField<Child>(
            value: _selectedChild,
            items: _children
                .map(
                  (child) =>
                      DropdownMenuItem(value: child, child: Text(child.name)),
                )
                .toList(),
            onChanged: _selectionLocked
                ? null
                : (child) {
                    if (child != null) _updateSelection(child: child);
                  },
          ),
          const SizedBox(height: SKSpacing.x4),
          Text(
            'Выберите абонемент',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SKSpacing.x2),
          ..._plans.map(
            (plan) => Padding(
              padding: const EdgeInsets.only(bottom: SKSpacing.x2),
              child: _PlanCard(
                plan: plan,
                selected: _selectedPlan?.id == plan.id,
                onTap: _selectionLocked
                    ? null
                    : () => _updateSelection(plan: plan),
              ),
            ),
          ),
          if (_quoteLoading) const LinearProgressIndicator(),
          if (_quote != null)
            Padding(
              padding: const EdgeInsets.only(top: SKSpacing.x3),
              child: Text(
                'К оплате: ${_formatTenge(_quote!.amountTenge)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: SKSpacing.x2),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_paymentMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: SKSpacing.x2),
              child: Text(_paymentMessage!),
            ),
          const SizedBox(height: SKSpacing.x4),
          PrimaryButton(
            label: _phase == _PassPaymentPhase.paid
                ? 'Готово'
                : _phase == _PassPaymentPhase.opened
                    ? _paymentUrlOpenFailed
                        ? 'Открыть оплату'
                        : 'Проверить оплату'
                    : _busy
                        ? 'Проверяем…'
                        : _activeCheckoutSelection != null
                            ? 'Повторить оплату'
                            : 'Перейти к оплате',
            onPressed: _phase == _PassPaymentPhase.paid
                ? () => Navigator.of(context).pop(true)
                : _phase == _PassPaymentPhase.opened
                    ? (_paymentUrlOpenFailed
                        ? _openPaymentUrl
                        : _checkPaymentStatus)
                    : (_quote == null || _busy ? null : _startPayment),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });
  final PassPlan plan;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SolidCard(
        onTap: onTap,
        padding: const EdgeInsets.all(SKSpacing.x4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(
                      '${plan.visitLimit} посещения · ${plan.validityDays} дней'),
                  if (plan.dailyLimit == 1) const Text('До 1 посещения в день'),
                  Text(_formatTenge(plan.priceTenge)),
                ],
              ),
            ),
            Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off),
          ],
        ),
      );
}

class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message),
          const SizedBox(height: SKSpacing.x4),
          SecondaryButton(
              label: 'Повторить', fullWidth: true, onPressed: onRetry),
        ],
      );
}

String _formatTenge(int value) {
  final digits = value.toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(?<=\d)(?=(\d{3})+$)'),
    (_) => ' ',
  );
  return '$grouped ₸';
}

class _NoChildren extends StatelessWidget {
  const _NoChildren({required this.onOpenProfile});
  final VoidCallback onOpenProfile;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(SKSpacing.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Чтобы оформить абонемент, добавьте ребёнка.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: SKSpacing.x3),
            PrimaryButton(label: 'Добавить ребёнка', onPressed: onOpenProfile),
          ],
        ),
      );
}
