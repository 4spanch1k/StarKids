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
import '../../data/api_issued_ticket_repository.dart';
import '../../domain/issued_ticket.dart';
import '../../domain/issued_ticket_repository.dart';
import '../sheets/ticket_purchase_flow_sheet.dart';
import 'ticket_detail_page.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key, this.repository});

  final IssuedTicketRepository? repository;

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  late final IssuedTicketRepository _repository =
      widget.repository ?? ServiceRegistry.issuedTicketRepository;
  List<IssuedTicket> _tickets = const [];
  bool _isLoading = true;
  String? _errorMessage;

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
    try {
      final tickets = List<IssuedTicket>.of(
        await _repository.listIssuedTickets(),
      );
      if (!mounted) return;
      tickets.sort(_compareTickets);
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    } on IssuedTicketApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось загрузить билеты. Попробуйте еще раз.';
      });
    }
  }

  Future<void> _openPurchase() async {
    final completed = await showTicketPurchaseFlowSheet(context);
    if (!mounted || completed != true) return;
    await _loadTickets();
  }

  Future<void> _openTicket(IssuedTicket ticket) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TicketDetailPage(
          ticketId: ticket.ticketId,
          initialTicket: ticket,
          repository: _repository,
        ),
      ),
    );
    if (mounted) await _loadTickets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: GlassAppBar(
        leading: const SizedBox(width: 44),
        title: Text(
          'Мои билеты',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      bottomNavigationBar: const StarKidsRootNavigation(current: 'tickets'),
      body: StarKidsCosmicCanvas(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _loadTickets,
            child: _body(context),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_isLoading && _tickets.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 260),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_errorMessage != null && _tickets.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          SKSpacing.x5,
          SKSpacing.x6,
          SKSpacing.x5,
          120,
        ),
        children: [
          _TicketsStateCard(
            key: const ValueKey('tickets-error'),
            title: 'Не удалось загрузить билеты',
            description: _errorMessage!,
            action: SecondaryButton(
              label: 'Повторить',
              fullWidth: true,
              onPressed: _loadTickets,
            ),
          ),
        ],
      );
    }

    if (_tickets.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          SKSpacing.x5,
          SKSpacing.x6,
          SKSpacing.x5,
          120,
        ),
        children: [
          _TicketsStateCard(
            key: const ValueKey('tickets-empty'),
            title: 'У вас пока нет билетов',
            description:
                'Купите билет, и он появится здесь после подтверждения оплаты.',
            action: PrimaryButton(
              label: 'Купить билет',
              icon: Icons.arrow_forward_rounded,
              onPressed: _openPurchase,
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        SKSpacing.x5,
        SKSpacing.x4,
        SKSpacing.x5,
        120,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Билеты к посещению',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            TextButton(
              onPressed: _openPurchase,
              child: const Text('Купить билет'),
            ),
          ],
        ),
        const SizedBox(height: SKSpacing.x4),
        ..._tickets.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: SKSpacing.x3),
                child: _IssuedTicketCard(
                  key: ValueKey(entry.value.ticketId),
                  ticket: entry.value,
                  revealDelay: starKidsStaggerDelay(entry.key),
                  onTap: () => _openTicket(entry.value),
                ),
              ),
            ),
      ],
    );
  }
}

int _compareTickets(IssuedTicket a, IssuedTicket b) {
  if (a.visitDate == null && b.visitDate == null) return 0;
  if (a.visitDate == null) return 1;
  if (b.visitDate == null) return -1;
  return a.visitDate!.compareTo(b.visitDate!);
}

class _TicketsStateCard extends StatelessWidget {
  const _TicketsStateCard({
    super.key,
    required this.title,
    required this.description,
    required this.action,
  });

  final String title;
  final String description;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SolidCard(
      padding: const EdgeInsets.all(SKSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.headlineSmall),
          const SizedBox(height: SKSpacing.x2),
          Text(description, style: textTheme.bodyLarge),
          const SizedBox(height: SKSpacing.x5),
          action,
        ],
      ),
    );
  }
}

class _IssuedTicketCard extends StatelessWidget {
  const _IssuedTicketCard({
    super.key,
    required this.ticket,
    required this.revealDelay,
    required this.onTap,
  });

  final IssuedTicket ticket;
  final Duration revealDelay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = SKTheme.of(context).colors;
    return StarKidsReveal(
      delay: revealDelay,
      child: SolidCard(
        onTap: onTap,
        padding: const EdgeInsets.all(SKSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(ticket.title, style: textTheme.titleLarge),
                ),
                Text(
                  ticket.isIssued ? 'Действует' : ticket.status,
                  style: textTheme.labelLarge?.copyWith(color: colors.success),
                ),
              ],
            ),
            const SizedBox(height: SKSpacing.x3),
            Text(ticket.ticketNumber, style: textTheme.titleMedium),
            const SizedBox(height: SKSpacing.x2),
            Text(ticket.branchName, style: textTheme.bodyMedium),
            const SizedBox(height: SKSpacing.x1),
            Text(
              _formatTicketDate(ticket.visitDate),
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: SKSpacing.x1),
            Text('${ticket.priceTenge} тг', style: textTheme.bodyMedium),
            const SizedBox(height: SKSpacing.x3),
            SecondaryButton(
              label: 'Открыть билет',
              fullWidth: true,
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTicketDate(DateTime? date) {
  if (date == null) return 'Дата посещения не выбрана';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
