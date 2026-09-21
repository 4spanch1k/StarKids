import 'dart:async';

import 'package:flutter/services.dart';

import '../../../../core/storage/local_storage.dart';
import '../../../../core/utils/result.dart';
import '../../domain/ticket_purchase.dart';
import '../../domain/ticket_purchase_repository.dart';

enum PaymentReturnKind { success, failure }

enum PaymentCheckoutKind { ticket, pass }

class PaymentReturnEvent {
  const PaymentReturnEvent({
    required this.paymentId,
    required this.kind,
    required this.checkoutKind,
    this.status,
    this.errorMessage,
  });

  final String paymentId;
  final PaymentReturnKind kind;
  final PaymentCheckoutKind checkoutKind;
  final TicketPaymentStatus? status;
  final String? errorMessage;

  bool get isPaid => status?.status == TicketPaymentStatusValue.paid;
}

/// Bridges the native FreedomPay return URL to the authenticated payment API.
///
/// The callback URL is never treated as proof of payment. It only triggers a
/// bounded status refresh; the backend Result callback remains authoritative.
class PaymentReturnCoordinator {
  PaymentReturnCoordinator({
    required TicketPurchaseRepository purchaseRepository,
    required LocalStorage localStorage,
  })  : _purchaseRepository = purchaseRepository,
        _localStorage = localStorage;

  static const _channel = MethodChannel('kz.boombala/payment_return');

  final TicketPurchaseRepository _purchaseRepository;
  final LocalStorage _localStorage;
  final StreamController<PaymentReturnEvent> _events =
      StreamController<PaymentReturnEvent>.broadcast();

  Future<void>? _startFuture;
  String? _activePaymentId;
  String? _lastHandledLink;
  DateTime? _lastHandledAt;
  var _checkoutListenerAttached = false;

  Stream<PaymentReturnEvent> get events => _events.stream;

  bool get hasCheckoutListener => _checkoutListenerAttached;

  Future<void> start() {
    return _startFuture ??= _start();
  }

  Future<void> _start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'paymentLink') return;
      final rawLink = call.arguments?.toString();
      if (rawLink != null) await handleRawLink(rawLink);
    });

    try {
      final initialLink = await _channel.invokeMethod<String>('getInitialLink');
      if (initialLink != null) await handleRawLink(initialLink);
    } on PlatformException {
      // Deep-link delivery is best-effort on unsupported/test platforms.
    } on MissingPluginException {
      // Native bridge is unavailable in a pure Flutter test environment.
    }
  }

  Future<void> registerPayment(
    String paymentId, {
    PaymentCheckoutKind checkoutKind = PaymentCheckoutKind.ticket,
  }) async {
    final normalized = paymentId.trim();
    if (normalized.isEmpty) return;
    _activePaymentId = normalized;
    await _localStorage.savePendingPaymentId(normalized);
    await _localStorage.savePendingPaymentKind(checkoutKind.name);
  }

  /// Completes a payment that was registered for return handling.
  ///
  /// Both deep-link polling and an in-app status check can reach a terminal
  /// provider state. Only clear persisted state when it still belongs to this
  /// payment; a newer checkout must never be removed as a side effect.
  Future<void> completeRegisteredPayment(String paymentId) async {
    final normalized = paymentId.trim();
    if (normalized.isEmpty) return;
    if (_activePaymentId == normalized) {
      _activePaymentId = null;
    }
    final persistedPaymentId = await _localStorage.readPendingPaymentId();
    if (persistedPaymentId == normalized) {
      await _localStorage.clearPendingPaymentId();
      await _localStorage.clearPendingPaymentKind();
    }
  }

  void attachCheckoutListener() {
    _checkoutListenerAttached = true;
  }

  void detachCheckoutListener() {
    _checkoutListenerAttached = false;
  }

  Future<void> handleRawLink(String rawLink) async {
    final uri = Uri.tryParse(rawLink);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'starkids' ||
        uri.host.toLowerCase() != 'payments') {
      return;
    }

    final path = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final kind = switch (path.toLowerCase()) {
      'success' => PaymentReturnKind.success,
      'failure' => PaymentReturnKind.failure,
      _ => null,
    };
    if (kind == null) return;

    final now = DateTime.now();
    if (_lastHandledLink == rawLink &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 10)) {
      return;
    }
    _lastHandledLink = rawLink;
    _lastHandledAt = now;

    final explicitPaymentId =
        uri.queryParameters['paymentId'] ?? uri.queryParameters['payment_id'];
    final paymentId = explicitPaymentId?.trim().isNotEmpty == true
        ? explicitPaymentId!.trim()
        : _activePaymentId ?? await _localStorage.readPendingPaymentId();
    if (paymentId == null || paymentId.trim().isEmpty) return;

    final checkoutKind = _activePaymentId == paymentId
        ? await _readCheckoutKind()
        : _parseCheckoutKind(await _localStorage.readPendingPaymentKind());

    final event = await _resolveStatus(paymentId.trim(), kind, checkoutKind);
    _events.add(event);

    if (event.status?.isFinal == true) {
      await completeRegisteredPayment(paymentId);
    }
  }

  Future<PaymentReturnEvent> _resolveStatus(
    String paymentId,
    PaymentReturnKind kind,
    PaymentCheckoutKind checkoutKind,
  ) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      final result = await _purchaseRepository.getPaymentStatus(paymentId);
      if (result is Failure<TicketPaymentStatus>) {
        return PaymentReturnEvent(
          paymentId: paymentId,
          kind: kind,
          checkoutKind: checkoutKind,
          errorMessage: result.message,
        );
      }

      final status = (result as Success<TicketPaymentStatus>).data;
      if (status.isFinal || attempt == 5) {
        return PaymentReturnEvent(
          paymentId: paymentId,
          kind: kind,
          checkoutKind: checkoutKind,
          status: status,
        );
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    throw StateError('Payment status polling ended unexpectedly');
  }

  Future<PaymentCheckoutKind> _readCheckoutKind() async {
    return _parseCheckoutKind(await _localStorage.readPendingPaymentKind());
  }

  PaymentCheckoutKind _parseCheckoutKind(String? raw) {
    return raw == PaymentCheckoutKind.pass.name
        ? PaymentCheckoutKind.pass
        : PaymentCheckoutKind.ticket;
  }
}
