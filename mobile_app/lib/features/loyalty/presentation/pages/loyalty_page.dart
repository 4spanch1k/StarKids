import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/star_kids_cosmic_canvas.dart';
import '../controllers/loyalty_controller.dart';
import '../../domain/loyalty_transaction.dart';
import '../loyalty_transaction_presentation.dart';

class LoyaltyPage extends StatefulWidget {
  const LoyaltyPage({super.key, this.controller});

  final LoyaltyController? controller;

  @override
  State<LoyaltyPage> createState() => _LoyaltyPageState();
}

class _LoyaltyPageState extends State<LoyaltyPage> {
  late final LoyaltyController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ServiceRegistry.loyaltyController;
    unawaited(_controller.load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        leading: GlassIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Бонусы', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: StarKidsCosmicCanvas(
        child: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => RefreshIndicator(
              onRefresh: _controller.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(
                  SKSpacing.x4,
                  SKSpacing.x4,
                  SKSpacing.x4,
                  SKSpacing.x8,
                ),
                children: [
                  _buildSummary(context),
                  const SizedBox(height: SKSpacing.x6),
                  _buildHistory(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final account = _controller.account;
    if (_controller.status == LoyaltyViewStatus.loading && account == null) {
      return const SolidCard(
        key: ValueKey('loyalty-summary-loading'),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_controller.status == LoyaltyViewStatus.error && account == null) {
      return SolidCard(
        key: const ValueKey('loyalty-summary-error'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Бонусы временно недоступны',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: SKSpacing.x2),
            Text(
              _controller.errorMessage ?? 'Попробуйте еще раз.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SKSpacing.x3),
            SecondaryButton(label: 'Повторить', onPressed: _controller.load),
          ],
        ),
      );
    }
    final value = account?.balance ?? 0;
    return SolidCard(
      key: const ValueKey('loyalty-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Баланс бонусов',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SKSpacing.x1),
          Text(
            '${_format(value)} бонусов',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: SKSpacing.x4),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Начислено всего',
                  value: _format(account?.lifetimeEarned ?? 0),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Использовано',
                  value: _format(account?.lifetimeSpent ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(BuildContext context) {
    final visible = _controller.transactions
        .map(
          (item) => (item: item, presentation: presentLoyaltyTransaction(item)),
        )
        .where((entry) => entry.presentation.amountLabel.isNotEmpty)
        .toList(growable: false);
    return Column(
      key: const ValueKey('loyalty-history'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('История операций', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: SKSpacing.x3),
        if (_controller.transactionsErrorMessage != null && visible.isEmpty)
          SolidCard(
            key: const ValueKey('loyalty-history-error'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _controller.transactionsErrorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: SKSpacing.x3),
                SecondaryButton(
                  label: 'Повторить',
                  onPressed: () => _controller.load(),
                ),
              ],
            ),
          )
        else if (visible.isEmpty && !_controller.transactionsLoading)
          SolidCard(
            key: const ValueKey('loyalty-history-empty'),
            child: Text(
              'Операций пока нет',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else ...[
          for (final entry in visible) ...[
            _TransactionTile(
              transaction: entry.item,
              presentation: entry.presentation,
            ),
            const SizedBox(height: SKSpacing.x2),
          ],
          if (_controller.transactionsLoading)
            const Padding(
              padding: EdgeInsets.all(SKSpacing.x3),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_controller.hasMoreTransactions)
            SecondaryButton(
              label: 'Показать еще',
              onPressed: _controller.loadMoreTransactions,
            ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SKSpacing.x1),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.presentation,
  });
  final LoyaltyTransaction transaction;
  final LoyaltyTransactionPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final colors = SKTheme.of(context).colors;
    return SolidCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: SKSpacing.x1),
                Text(
                  DateFormat(
                    'dd.MM.yyyy, HH:mm',
                  ).format(transaction.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (presentation.subtitle?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: SKSpacing.x1),
                  Text(
                    presentation.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${presentation.amountLabel} б.',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: presentation.isPositive
                      ? colors.success
                      : colors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

String _format(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(raw[index]);
  }
  return buffer.toString();
}
