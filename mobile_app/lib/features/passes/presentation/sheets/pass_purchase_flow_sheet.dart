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

class _PassPurchaseFlowSheet extends StatefulWidget {
  const _PassPurchaseFlowSheet(
      {required this.repository, required this.scrollController});
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
  _PassPaymentPhase _phase = _PassPaymentPhase.idle;
  String? _idempotencyKey;
  String? _selectionKey;
  String? _paymentId;
  StreamSubscription<PaymentReturnEvent>? _subscription;
  var _loading = true;
  var _quoteLoading = false;
  var _plansLoading = false;
  final Set<String> _existingPassIds = <String>{};

  bool get _busy =>
      _phase == _PassPaymentPhase.starting ||
      _phase == _PassPaymentPhase.checking;

  @override
  void initState() {
    super.initState();
    ServiceRegistry.paymentReturnCoordinator.attachCheckoutListener();
    _subscription =
        ServiceRegistry.paymentReturnCoordinator.events.listen(_handleReturn);
    _load();
  }

  @override
  void dispose() {
    ServiceRegistry.paymentReturnCoordinator.detachCheckoutListener();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    final childrenController = ServiceRegistry.childrenController;
    if (childrenController.status != ChildrenStatus.success &&
        childrenController.status != ChildrenStatus.empty) {
      await childrenController.load();
    }
    if (!mounted) return;
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
    if (existing is Success<List<CustomerPass>>) {
      _existingPassIds.addAll(existing.data.map((pass) => pass.id));
    }
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
        _error = result.message;
      });
      return;
    }
    _plans = (result as Success<List<PassPlan>>).data;
    setState(() {
      _plansLoading = false;
      _loading = false;
      _error = null;
    });
    if (_plans.isNotEmpty) {
      _selectedPlan = _plans.first;
      await _refreshQuote();
    }
  }

  void _updateSelection({Child? child, PassPlan? plan}) {
    final nextChild = child ?? _selectedChild;
    final nextPlan = plan ?? _selectedPlan;
    final nextKey = nextChild == null || nextPlan == null
        ? null
        : '${nextChild.id}:${nextPlan.id}:${ServiceRegistry.selectedBranchController.selectedBranch.id}';
    if (nextKey != _selectionKey) {
      _idempotencyKey = null;
      _selectionKey = nextKey;
    }
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
    setState(() => _quoteLoading = true);
    final result = await widget.repository.quote(
      childId: child.id,
      passPlanId: plan.id,
      branchId: ServiceRegistry.selectedBranchController.selectedBranch.id,
    );
    if (!mounted) return;
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
    if (child == null || plan == null || _quote == null || _busy) return;
    _idempotencyKey ??= _newIdempotencyKey();
    setState(() {
      _phase = _PassPaymentPhase.starting;
      _paymentMessage = null;
      _error = null;
    });
    final result = await widget.repository.startPayment(
      childId: child.id,
      passPlanId: plan.id,
      branchId: ServiceRegistry.selectedBranchController.selectedBranch.id,
      idempotencyKey: _idempotencyKey!,
    );
    if (!mounted) return;
    if (result is Failure<PassPaymentStart>) {
      setState(() {
        _phase = _PassPaymentPhase.failed;
        _error = result.message;
      });
      return;
    }
    final payment = (result as Success<PassPaymentStart>).data;
    _paymentId = payment.paymentId;
    if (payment.status == 'paid') {
      await _reconcilePaid();
      return;
    }
    await ServiceRegistry.paymentReturnCoordinator.registerPayment(
      payment.paymentId,
      checkoutKind: PaymentCheckoutKind.pass,
    );
    setState(() {
      _phase = _PassPaymentPhase.opened;
      _paymentMessage =
          'Откройте страницу оплаты. После оплаты вернитесь в Boom Bala.';
    });
    final opened = await ServiceRegistry.paymentUrlLauncher(payment.paymentUrl);
    if (!opened && mounted)
      setState(() {
        _phase = _PassPaymentPhase.failed;
        _error = 'Не удалось открыть страницу оплаты.';
      });
  }

  Future<void> _handleReturn(PaymentReturnEvent event) async {
    if (!mounted ||
        event.checkoutKind != PaymentCheckoutKind.pass ||
        event.paymentId != _paymentId) return;
    if (event.isPaid) {
      await _reconcilePaid();
    } else if (event.status != null && event.status!.isFinal) {
      setState(() {
        _phase = _PassPaymentPhase.failed;
        _error = event.errorMessage ??
            event.status!.failureReason ??
            'Оплата не прошла.';
      });
    } else if (mounted) {
      setState(() {
        _phase = _PassPaymentPhase.checking;
        _paymentMessage = 'Проверяем оплату…';
      });
    }
  }

  Future<void> _reconcilePaid() async {
    setState(() {
      _phase = _PassPaymentPhase.checking;
      _paymentMessage = 'Оплата подтверждена. Выпускаем абонемент…';
    });
    for (var attempt = 0; attempt < 6; attempt++) {
      final result = await widget.repository.listPasses();
      if (result is Success<List<CustomerPass>>) {
        final passes = result.data;
        final found = passes
            .where((pass) =>
                !_existingPassIds.contains(pass.id) &&
                pass.childId == _selectedChild?.id &&
                pass.passPlanId == _selectedPlan?.id)
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
          child: Center(child: CircularProgressIndicator()));
    if (_children.isEmpty)
      return _NoChildren(onOpenProfile: () {
        Navigator.of(context).pop();
        Navigator.of(context).pushNamed(AppRoutes.profile);
      });
    if (_error != null && _plans.isEmpty)
      return Padding(
          padding: const EdgeInsets.all(SKSpacing.x5), child: Text(_error!));
    if (_plans.isEmpty)
      return const Padding(
          padding: EdgeInsets.all(SKSpacing.x5),
          child:
              Text('Сейчас нет доступных абонементов для выбранного филиала.'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SKSpacing.x5, SKSpacing.x2, SKSpacing.x5, SKSpacing.x6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Выберите ребёнка',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: SKSpacing.x2),
        DropdownButtonFormField<Child>(
            value: _selectedChild,
            items: _children
                .map((child) =>
                    DropdownMenuItem(value: child, child: Text(child.name)))
                .toList(),
            onChanged: (child) {
              if (child != null) _updateSelection(child: child);
            }),
        const SizedBox(height: SKSpacing.x4),
        Text('Выберите абонемент',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: SKSpacing.x2),
        ..._plans.map((plan) => Padding(
            padding: const EdgeInsets.only(bottom: SKSpacing.x2),
            child: _PlanCard(
                plan: plan,
                selected: _selectedPlan?.id == plan.id,
                onTap: () => _updateSelection(plan: plan)))),
        if (_quoteLoading) const LinearProgressIndicator(),
        if (_quote != null)
          Padding(
              padding: const EdgeInsets.only(top: SKSpacing.x3),
              child: Text('К оплате: ${_quote!.amountTenge} тг',
                  style: Theme.of(context).textTheme.titleLarge)),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: SKSpacing.x2),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_paymentMessage != null)
          Padding(
              padding: const EdgeInsets.only(top: SKSpacing.x2),
              child: Text(_paymentMessage!)),
        const SizedBox(height: SKSpacing.x4),
        PrimaryButton(
            label: _phase == _PassPaymentPhase.paid
                ? 'Готово'
                : _busy
                    ? 'Проверяем…'
                    : 'Перейти к оплате',
            onPressed: _phase == _PassPaymentPhase.paid
                ? () => Navigator.of(context).pop(true)
                : (_quote == null || _busy ? null : _startPayment)),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(
      {required this.plan, required this.selected, required this.onTap});
  final PassPlan plan;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SolidCard(
      onTap: onTap,
      padding: const EdgeInsets.all(SKSpacing.x4),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
          Text('${plan.visitLimit} посещения · ${plan.validityDays} дней'),
          Text('${plan.priceTenge} тг')
        ])),
        Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off)
      ]));
}

class _NoChildren extends StatelessWidget {
  const _NoChildren({required this.onOpenProfile});
  final VoidCallback onOpenProfile;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(SKSpacing.x5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Чтобы оформить абонемент, добавьте ребёнка.',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: SKSpacing.x3),
        PrimaryButton(label: 'Добавить ребёнка', onPressed: onOpenProfile)
      ]));
}
