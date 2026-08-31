import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/star_kids_cosmic_canvas.dart';
import '../../data/api_issued_ticket_repository.dart';
import '../../domain/issued_ticket.dart';
import '../../domain/issued_ticket_repository.dart';

class TicketDetailPage extends StatefulWidget {
  const TicketDetailPage({
    super.key,
    required this.ticketId,
    this.initialTicket,
    this.repository,
  });

  final String ticketId;
  final IssuedTicket? initialTicket;
  final IssuedTicketRepository? repository;

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  late final IssuedTicketRepository _repository =
      widget.repository ?? ServiceRegistry.issuedTicketRepository;
  IssuedTicket? _ticket;
  bool _isLoading = true;
  String? _errorMessage;
  String? _qrPayload;
  String? _qrErrorMessage;
  bool _isQrLoading = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.initialTicket;
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final ticket = await _repository.getIssuedTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _isLoading = false;
      });
      if (ticket.isIssued) unawaited(_loadQrPayload());
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
        _errorMessage = 'Не удалось загрузить билет. Попробуйте еще раз.';
      });
    }
  }

  Future<void> _loadQrPayload() async {
    if (_isQrLoading || _ticket?.isIssued != true) return;
    setState(() {
      _isQrLoading = true;
      _qrErrorMessage = null;
    });
    try {
      final payload =
          await _repository.getIssuedTicketQrPayload(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _qrPayload = payload;
        _isQrLoading = false;
      });
    } on IssuedTicketApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isQrLoading = false;
        _qrErrorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isQrLoading = false;
        _qrErrorMessage = 'Не удалось загрузить QR-код. Попробуйте еще раз.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        leading: GlassIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Билет', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: StarKidsCosmicCanvas(
        child: SafeArea(bottom: false, child: _body(context)),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_isLoading && _ticket == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ticket == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SKSpacing.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage ?? 'Билет не найден.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: SKSpacing.x4),
              PrimaryButton(label: 'Повторить', onPressed: _loadTicket),
            ],
          ),
        ),
      );
    }

    final ticket = _ticket!;
    final textTheme = Theme.of(context).textTheme;
    final colors = SKTheme.of(context).colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SKSpacing.x5,
        SKSpacing.x5,
        SKSpacing.x5,
        100,
      ),
      children: [
        SolidCard(
          padding: const EdgeInsets.all(SKSpacing.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ticket.ticketNumber, style: textTheme.displaySmall),
              const SizedBox(height: SKSpacing.x3),
              Text(ticket.title, style: textTheme.titleLarge),
              const SizedBox(height: SKSpacing.x4),
              _DetailRow(label: 'Филиал', value: ticket.branchName),
              _DetailRow(
                label: 'Дата посещения',
                value: _formatTicketDate(ticket.visitDate),
              ),
              _DetailRow(label: 'Стоимость', value: '${ticket.priceTenge} тг'),
              _DetailRow(
                label: 'Статус',
                value: ticket.isIssued ? 'Готов к посещению' : ticket.status,
                valueColor: colors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: SKSpacing.x4),
        _QrSection(
          payload: _qrPayload,
          isLoading: _isQrLoading,
          errorMessage: _qrErrorMessage,
          onRetry: _loadQrPayload,
        ),
      ],
    );
  }
}

class _QrSection extends StatelessWidget {
  const _QrSection({
    required this.payload,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final String? payload;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading && payload == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null && payload == null) {
      return Column(
        children: [
          Text(errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: SKSpacing.x3),
          PrimaryButton(label: 'Повторить', onPressed: onRetry),
        ],
      );
    }
    if (payload == null) return const SizedBox.shrink();
    return Column(
      children: [
        SolidCard(
          padding: const EdgeInsets.all(SKSpacing.x4),
          child: QrImageView(
            data: payload!,
            size: 240,
            padding: const EdgeInsets.all(SKSpacing.x3),
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: SKSpacing.x3),
        Text(
          'Покажите QR сотруднику на входе.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: SKSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          const SizedBox(width: SKSpacing.x3),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
