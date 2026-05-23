import 'package:flutter/material.dart';

import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_bottom_sheet.dart';
import '../../../../core/design_system/widgets/glass_card.dart';

enum TicketsEntryAction { myTickets, buyTicket }

Future<TicketsEntryAction?> showTicketsEntrySheet(BuildContext context) {
  return showGlassBottomSheet<TicketsEntryAction>(
    context: context,
    title: 'Билеты',
    initialSize: 0.55,
    builder: (context, _) => const _TicketsEntryBody(),
  );
}

class _TicketsEntryBody extends StatelessWidget {
  const _TicketsEntryBody();

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SKSpacing.x5,
        SKSpacing.x4,
        SKSpacing.x5,
        SKSpacing.x5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Выберите, что хотите сделать сейчас.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textSecondary,
                ),
          ),
          const SizedBox(height: SKSpacing.x4),
          _TicketsEntryActionCard(
            key: const ValueKey('my-tickets-action'),
            icon: Icons.confirmation_num_rounded,
            title: 'Мои билеты',
            subtitle: 'История и активные билеты',
            onTap: () =>
                Navigator.of(context).pop(TicketsEntryAction.myTickets),
          ),
          const SizedBox(height: SKSpacing.x3),
          _TicketsEntryActionCard(
            key: const ValueKey('buy-ticket-action'),
            icon: Icons.shopping_bag_rounded,
            title: 'Купить входной билет',
            subtitle: 'Выберите филиал, дату и количество',
            onTap: () =>
                Navigator.of(context).pop(TicketsEntryAction.buyTicket),
          ),
        ],
      ),
    );
  }
}

class _TicketsEntryActionCard extends StatelessWidget {
  const _TicketsEntryActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;

    return SolidCard(
      radius: SKRadius.xl,
      padding: const EdgeInsets.all(SKSpacing.x4),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(SKRadius.lg),
            ),
            child: Icon(icon, size: 24, color: c.accent),
          ),
          const SizedBox(width: SKSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: SKSpacing.x1),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SKSpacing.x2),
          Icon(Icons.chevron_right_rounded, color: c.textSecondary),
        ],
      ),
    );
  }
}
