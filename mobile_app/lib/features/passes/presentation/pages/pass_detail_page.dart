import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/storage/local_storage.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/star_kids_cosmic_canvas.dart';
import '../../../../app/di/service_registry.dart';
import '../../domain/pass.dart';
import '../../domain/pass_repository.dart';

class PassDetailPage extends StatefulWidget {
  const PassDetailPage({
    super.key,
    required this.passId,
    this.initialPass,
    this.repository,
    this.localStorage,
  });

  final String passId;
  final CustomerPass? initialPass;
  final PassRepository? repository;
  final LocalStorage? localStorage;

  @override
  State<PassDetailPage> createState() => _PassDetailPageState();
}

class _PassDetailPageState extends State<PassDetailPage> {
  late final PassRepository _repository =
      widget.repository ?? ServiceRegistry.passRepository;
  late final LocalStorage _storage =
      widget.localStorage ?? ServiceRegistry.localStorage;
  CustomerPass? _pass;
  String? _qrPayload;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isQrLoading = false;

  @override
  void initState() {
    super.initState();
    _pass = widget.initialPass;
    _restoreAndRefresh();
  }

  Future<void> _restoreAndRefresh() async {
    if (_pass?.isActive == true) {
      _qrPayload = await _storage.readPassQrPayload(widget.passId);
      if (mounted) setState(() {});
    }
    final result = await _repository.getPass(widget.passId);
    if (!mounted) return;
    if (result is Failure<CustomerPass>) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
      return;
    }
    final pass = (result as Success<CustomerPass>).data;
    setState(() {
      _pass = pass;
      _isLoading = false;
      _errorMessage = null;
    });
    if (!pass.isActive) {
      await _storage.clearPassQrPayload(pass.id);
      if (mounted) setState(() => _qrPayload = null);
    } else {
      unawaited(_refreshQr());
    }
  }

  Future<void> _refreshQr() async {
    if (_pass?.isActive != true) return;
    setState(() => _isQrLoading = true);
    final result = await _repository.getPassQrPayload(widget.passId);
    if (!mounted) return;
    if (result is Success<String>) {
      await _storage.savePassQrPayload(widget.passId, result.data);
      if (mounted) setState(() => _qrPayload = result.data);
    }
    if (mounted) setState(() => _isQrLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final pass = _pass;
    return Scaffold(
      appBar: GlassAppBar(
        title: Text('Абонемент', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: StarKidsCosmicCanvas(
        child: SafeArea(
          child: _isLoading && pass == null
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null && pass == null
                  ? _error(context)
                  : _content(context, pass!),
        ),
      ),
    );
  }

  Widget _error(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(SKSpacing.x5),
          child: _StateCard(
            title: 'Не удалось открыть абонемент',
            description: _errorMessage!,
            action: SecondaryButton(
                label: 'Повторить',
                fullWidth: true,
                onPressed: _restoreAndRefresh),
          ),
        ),
      );

  Widget _content(BuildContext context, CustomerPass pass) {
    final colors = SKTheme.of(context).colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          SKSpacing.x5, SKSpacing.x5, SKSpacing.x5, SKSpacing.x8),
      children: [
        SolidCard(
          padding: const EdgeInsets.all(SKSpacing.x5),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(pass.planName,
                      style: Theme.of(context).textTheme.headlineSmall)),
              Text(customerPassStatusLabel(pass.status),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: pass.isActive
                          ? colors.success
                          : colors.textSecondary)),
            ]),
            const SizedBox(height: SKSpacing.x3),
            Text('Ребёнок: ${pass.childName}',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: SKSpacing.x2),
            Text(
                'Осталось посещений: ${pass.remainingVisits} из ${pass.visitLimit}'),
            Text('Действует до: ${_formatDate(pass.expiresAt)}'),
            if (pass.branchId != null) Text('Филиал: ${pass.branchId}'),
          ]),
        ),
        const SizedBox(height: SKSpacing.x4),
        if (pass.isActive && _qrPayload != null)
          SolidCard(
            padding: const EdgeInsets.all(SKSpacing.x5),
            child: Column(children: [
              Text('Покажите QR-код на входе',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: SKSpacing.x4),
              QrImageView(
                  data: _qrPayload!, size: 240, backgroundColor: Colors.white),
              if (_isQrLoading)
                const Padding(
                    padding: EdgeInsets.only(top: SKSpacing.x2),
                    child: LinearProgressIndicator()),
            ]),
          )
        else if (pass.isActive)
          _StateCard(
              title: 'QR-код загружается',
              description: 'Проверьте соединение и повторите попытку.',
              action: SecondaryButton(
                  label: 'Повторить', fullWidth: true, onPressed: _refreshQr))
        else
          _StateCard(
              title: 'QR-код недоступен',
              description: 'Абонемент больше нельзя использовать.',
              action: const SizedBox.shrink()),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard(
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
          Text(description),
          if (action is! SizedBox) ...[
            const SizedBox(height: SKSpacing.x4),
            action
          ],
        ]),
      );
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
