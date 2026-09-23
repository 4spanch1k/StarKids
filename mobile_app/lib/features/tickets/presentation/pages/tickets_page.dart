import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/widgets/star_kids_root_navigation.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/star_kids_cosmic_canvas.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/utils/result.dart';
import '../../../passes/domain/pass.dart';
import '../../../passes/domain/pass_repository.dart';
import '../../../passes/presentation/pages/pass_detail_page.dart';
import '../../../passes/presentation/sheets/pass_purchase_flow_sheet.dart';
import '../../data/api_issued_ticket_repository.dart';
import '../../domain/issued_ticket.dart';
import '../../domain/issued_ticket_repository.dart';
import '../models/tickets_page_args.dart';
import '../sheets/ticket_purchase_flow_sheet.dart';
import 'ticket_detail_page.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage(
      {super.key,
      this.repository,
      this.passRepository,
      this.initialSection = TicketsSection.tickets});
  final IssuedTicketRepository? repository;
  final PassRepository? passRepository;
  final TicketsSection initialSection;
  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  late final IssuedTicketRepository _repository =
      widget.repository ?? ServiceRegistry.issuedTicketRepository;
  late final PassRepository _passRepository =
      widget.passRepository ?? ServiceRegistry.passRepository;
  late TicketsSection _section = widget.initialSection;
  List<IssuedTicket> _tickets = const [];
  List<CustomerPass> _passes = const [];
  List<PassPlan> _plans = const [];
  bool _ticketsLoading = true;
  bool _passesLoading = false;
  bool _passesLoaded = false;
  String? _ticketsError;
  String? _passesError;
  String? _plansError;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    if (_section == TicketsSection.passes) _loadPasses();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _ticketsLoading = true;
      _ticketsError = null;
    });
    try {
      final tickets =
          List<IssuedTicket>.of(await _repository.listIssuedTickets())
            ..sort(_compareTickets);
      if (mounted)
        setState(() {
          _tickets = tickets;
          _ticketsLoading = false;
        });
    } on IssuedTicketApiException catch (error) {
      if (mounted)
        setState(() {
          _ticketsLoading = false;
          _ticketsError = error.message;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _ticketsLoading = false;
          _ticketsError = 'Не удалось загрузить билеты. Попробуйте еще раз.';
        });
    }
  }

  Future<void> _loadPasses() async {
    setState(() {
      _passesLoading = true;
      _passesError = null;
      _plansError = null;
    });
    final results = await Future.wait([
      _passRepository.listPasses(),
      _passRepository.listPlans(
          branchId: ServiceRegistry.selectedBranchController.selectedBranch.id),
    ]);
    if (!mounted) return;
    final passesResult = results[0] as Result<List<CustomerPass>>;
    final plansResult = results[1] as Result<List<PassPlan>>;
    if (passesResult is Failure<List<CustomerPass>>) {
      setState(() {
        _passesLoading = false;
        _passesLoaded = true;
        _passesError = passesResult.message;
      });
      return;
    }
    setState(() {
      _passes = _sortPasses((passesResult as Success<List<CustomerPass>>).data);
      if (plansResult is Success<List<PassPlan>>) {
        _plans = plansResult.data;
        _plansError = null;
      } else {
        _plans = const [];
        _plansError = (plansResult as Failure<List<PassPlan>>).message;
      }
      _passesLoading = false;
      _passesLoaded = true;
      _passesError = null;
    });
  }

  Future<void> _selectSection(TicketsSection section) async {
    if (_section == section) return;
    setState(() => _section = section);
    if (section == TicketsSection.passes && !_passesLoaded) await _loadPasses();
  }

  Future<void> _openPurchase() async {
    final completed = await showTicketPurchaseFlowSheet(context);
    if (mounted && completed) await _loadTickets();
  }

  Future<void> _openPassPurchase() async {
    final completed =
        await showPassPurchaseFlowSheet(context, repository: _passRepository);
    if (mounted && completed) await _loadPasses();
  }

  Future<void> _openTicket(IssuedTicket ticket) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TicketDetailPage(
            ticketId: ticket.ticketId,
            initialTicket: ticket,
            repository: _repository)));
    if (mounted) await _loadTickets();
  }

  Future<void> _openPass(CustomerPass pass) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PassDetailPage(
            passId: pass.id, initialPass: pass, repository: _passRepository)));
    if (mounted) await _loadPasses();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        appBar: GlassAppBar(
            leading: const SizedBox(width: 44),
            title: Text('Мои билеты',
                style: Theme.of(context).textTheme.titleLarge)),
        bottomNavigationBar: const StarKidsRootNavigation(current: 'tickets'),
        body: StarKidsCosmicCanvas(
            child: SafeArea(bottom: false, child: _body(context))),
      );

  Widget _body(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(
                SKSpacing.x5, SKSpacing.x3, SKSpacing.x5, 0),
            child:
                _SectionToggle(section: _section, onChanged: _selectSection)),
        Expanded(
            child: _section == TicketsSection.tickets
                ? RefreshIndicator(
                    onRefresh: _loadTickets, child: _ticketsBody(context))
                : RefreshIndicator(
                    onRefresh: _loadPasses, child: _passesBody(context))),
      ]);

  Widget _ticketsBody(BuildContext context) {
    if (_ticketsLoading && _tickets.isEmpty) return _loadingList();
    if (_ticketsError != null && _tickets.isEmpty)
      return _stateList(_TicketsStateCard(
          title: 'Не удалось загрузить билеты',
          description: _ticketsError!,
          action: SecondaryButton(
              label: 'Повторить', fullWidth: true, onPressed: _loadTickets)));
    if (_tickets.isEmpty)
      return _stateList(_TicketsStateCard(
          title: 'У вас пока нет билетов',
          description:
              'Купите билет, и он появится здесь после подтверждения оплаты.',
          action:
              PrimaryButton(label: 'Купить билет', onPressed: _openPurchase)));
    return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            SKSpacing.x5, SKSpacing.x4, SKSpacing.x5, 120),
        children: [
          Row(children: [
            Expanded(
                child: Text('Билеты к посещению',
                    style: Theme.of(context).textTheme.headlineSmall)),
            TextButton(
                onPressed: _openPurchase, child: const Text('Купить билет'))
          ]),
          const SizedBox(height: SKSpacing.x4),
          ..._tickets.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: SKSpacing.x3),
              child: _IssuedTicketCard(
                  ticket: entry.value,
                  revealDelay: starKidsStaggerDelay(entry.key),
                  onTap: () => _openTicket(entry.value))))
        ]);
  }

  Widget _passesBody(BuildContext context) {
    if (_passesLoading && _passes.isEmpty) return _loadingList();
    if (_passesError != null && _passes.isEmpty)
      return _stateList(_TicketsStateCard(
          title: 'Не удалось загрузить абонементы',
          description: _passesError!,
          action: SecondaryButton(
              label: 'Повторить', fullWidth: true, onPressed: _loadPasses)));
    if (_plansError != null && _passes.isEmpty)
      return _stateList(_TicketsStateCard(
          title: 'Не удалось загрузить планы',
          description: _plansError!,
          action: SecondaryButton(
              label: 'Повторить', fullWidth: true, onPressed: _loadPasses)));
    if (_passes.isEmpty)
      return _stateList(_TicketsStateCard(
          title: 'Абонементов пока нет',
          description: _plans.isEmpty
              ? 'Для выбранного филиала сейчас нет доступных планов.'
              : 'Оформите абонемент для ребёнка и показывайте QR на входе.',
          action: _plans.isEmpty
              ? const SizedBox.shrink()
              : PrimaryButton(
                  label: 'Купить абонемент', onPressed: _openPassPurchase)));
    return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            SKSpacing.x5, SKSpacing.x4, SKSpacing.x5, 120),
        children: [
          Row(children: [
            Expanded(
                child: Text('Абонементы',
                    style: Theme.of(context).textTheme.headlineSmall)),
            TextButton(
                onPressed: _openPassPurchase, child: const Text('Купить'))
          ]),
          const SizedBox(height: SKSpacing.x4),
          ..._passes.map((pass) => Padding(
              padding: const EdgeInsets.only(bottom: SKSpacing.x3),
              child: _PassCard(pass: pass, onTap: () => _openPass(pass))))
        ]);
  }

  Widget _loadingList() =>
      ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
        SizedBox(height: 260),
        Center(child: CircularProgressIndicator())
      ]);
  Widget _stateList(Widget child) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          SKSpacing.x5, SKSpacing.x6, SKSpacing.x5, 120),
      children: [child]);
}

class _SectionToggle extends StatelessWidget {
  const _SectionToggle({required this.section, required this.onChanged});
  final TicketsSection section;
  final ValueChanged<TicketsSection> onChanged;
  @override
  Widget build(BuildContext context) =>
      SegmentedButton<TicketsSection>(segments: const [
        ButtonSegment(value: TicketsSection.tickets, label: Text('Билеты')),
        ButtonSegment(value: TicketsSection.passes, label: Text('Абонементы'))
      ], selected: {
        section
      }, onSelectionChanged: (value) => onChanged(value.first));
}

class _TicketsStateCard extends StatelessWidget {
  const _TicketsStateCard(
      {required this.title, required this.description, required this.action});
  final String title;
  final String description;
  final Widget action;
  @override
  Widget build(BuildContext context) => SolidCard(
      padding: const EdgeInsets.all(SKSpacing.x5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: SKSpacing.x2),
        Text(description, style: Theme.of(context).textTheme.bodyLarge),
        if (action is! SizedBox) ...[
          const SizedBox(height: SKSpacing.x5),
          action
        ]
      ]));
}

class _IssuedTicketCard extends StatelessWidget {
  const _IssuedTicketCard(
      {required this.ticket, required this.revealDelay, required this.onTap});
  final IssuedTicket ticket;
  final Duration revealDelay;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => StarKidsReveal(
      delay: revealDelay,
      child: SolidCard(
          onTap: onTap,
          padding: const EdgeInsets.all(SKSpacing.x4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(ticket.title,
                      style: Theme.of(context).textTheme.titleLarge)),
              Text(ticket.isIssued ? 'Действует' : ticket.status,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: SKTheme.of(context).colors.success))
            ]),
            const SizedBox(height: SKSpacing.x3),
            Text(ticket.ticketNumber,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: SKSpacing.x2),
            Text(ticket.branchName),
            Text(_formatTicketDate(ticket.visitDate)),
            const SizedBox(height: SKSpacing.x3),
            SecondaryButton(
                label: 'Открыть билет', fullWidth: true, onPressed: onTap)
          ])));
}

class _PassCard extends StatelessWidget {
  const _PassCard({required this.pass, required this.onTap});
  final CustomerPass pass;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SolidCard(
      onTap: onTap,
      padding: const EdgeInsets.all(SKSpacing.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(pass.planName,
                  style: Theme.of(context).textTheme.titleLarge)),
          Text(customerPassStatusLabel(pass.status),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: pass.isActive
                      ? SKTheme.of(context).colors.success
                      : SKTheme.of(context).colors.textSecondary))
        ]),
        const SizedBox(height: SKSpacing.x2),
        Text('Ребёнок: ${pass.childName}'),
        Text('Осталось: ${pass.remainingVisits} из ${pass.visitLimit}'),
        Text('До ${_formatPassDate(pass.expiresAt)}'),
        const SizedBox(height: SKSpacing.x3),
        SecondaryButton(
            label: 'Открыть абонемент', fullWidth: true, onPressed: onTap)
      ]));
}

int _compareTickets(IssuedTicket a, IssuedTicket b) {
  if (a.visitDate == null && b.visitDate == null) return 0;
  if (a.visitDate == null) return 1;
  if (b.visitDate == null) return -1;
  return a.visitDate!.compareTo(b.visitDate!);
}

List<CustomerPass> _sortPasses(List<CustomerPass> passes) {
  final result = List<CustomerPass>.of(passes);
  result.sort((a, b) {
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    return a.expiresAt.compareTo(b.expiresAt);
  });
  return result;
}

String _formatTicketDate(DateTime? date) => date == null
    ? 'Дата посещения не выбрана'
    : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
String _formatPassDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
