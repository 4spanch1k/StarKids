import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/utils/result.dart';
import '../../domain/customer_qr.dart';
import '../../domain/customer_qr_repository.dart';

class CustomerQrPage extends StatefulWidget {
  const CustomerQrPage({super.key, this.repository});

  final CustomerQrRepository? repository;

  @override
  State<CustomerQrPage> createState() => _CustomerQrPageState();
}

class _CustomerQrPageState extends State<CustomerQrPage>
    with WidgetsBindingObserver {
  late final CustomerQrRepository _repository =
      widget.repository ?? ServiceRegistry.customerQrRepository;
  CustomerQr? _qr;
  String? _errorMessage;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadQr());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_qr == null || _qr!.remaining <= const Duration(seconds: 20))) {
      unawaited(_loadQr());
    }
  }

  void _tick() {
    final qr = _qr;
    if (!mounted || qr == null) return;
    if (qr.isExpired || qr.remaining <= const Duration(seconds: 20)) {
      if (!_isLoading) unawaited(_loadQr());
    } else {
      setState(() {});
    }
  }

  Future<void> _loadQr() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _qr = null;
    });
    final result = await _repository.fetchCustomerQr();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result is Success<CustomerQr>) {
        _qr = result.data;
      } else {
        _errorMessage = (result as Failure<CustomerQr>).message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = SKTheme.of(context).colors;
    final qr = _qr;
    return Scaffold(
      appBar: GlassAppBar(
        title: Text('Мой QR', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SKSpacing.x5),
            child: Column(
              children: [
                Text(
                  'Покажите этот QR сотруднику Boom Bala, чтобы идентифицировать ваш аккаунт.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: SKSpacing.x5),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(SKSpacing.x10),
                    child: CircularProgressIndicator(),
                  )
                else if (_errorMessage != null)
                  SolidCard(
                    padding: const EdgeInsets.all(SKSpacing.x5),
                    child: Column(
                      children: [
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: SKSpacing.x4),
                        PrimaryButton(label: 'Повторить', onPressed: _loadQr),
                      ],
                    ),
                  )
                else if (qr != null && !qr.isExpired)
                  SolidCard(
                    padding: const EdgeInsets.all(SKSpacing.x4),
                    child: Column(
                      children: [
                        QrImageView(
                          data: qr.qrPayload,
                          size: 280,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: SKSpacing.x4),
                        Text(
                          'Обновится через ${_formatRemaining(qr.remaining)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRemaining(Duration value) {
    final seconds = value.inSeconds.clamp(0, 599).toInt();
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}
