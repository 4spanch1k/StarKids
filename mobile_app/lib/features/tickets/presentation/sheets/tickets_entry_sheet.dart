import 'package:flutter/material.dart';

import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_bottom_sheet.dart';

enum TicketsEntryAction { myTickets, buyTicket }

Future<TicketsEntryAction?> showTicketsEntrySheet(BuildContext context) {
  return showGlassBottomSheet<TicketsEntryAction>(
    context: context,
    title: 'Билеты',
    step: 'Покупка и история',
    initialSize: 0.48,
    minSize: 0.42,
    maxSize: 0.72,
    builder: (context, _) => const _TicketsEntryBody(),
  );
}

class _TicketsEntryBody extends StatelessWidget {
  const _TicketsEntryBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SKSpacing.x4,
        SKSpacing.x3,
        SKSpacing.x4,
        SKSpacing.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TicketsEntryActionCard(
            key: const ValueKey('buy-ticket-action'),
            icon: Icons.shopping_bag_rounded,
            title: 'Оформить покупку',
            subtitle: 'Филиал, дата и количество',
            onTap: () =>
                Navigator.of(context).pop(TicketsEntryAction.buyTicket),
          ),
          const SizedBox(height: SKSpacing.x3),
          _TicketsEntryActionCard(
            key: const ValueKey('my-tickets-action'),
            icon: Icons.confirmation_num_rounded,
            title: 'Мои билеты',
            subtitle: 'Активные билеты и история',
            onTap: () =>
                Navigator.of(context).pop(TicketsEntryAction.myTickets),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SKRadius.xl),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(SKSpacing.x3),
          decoration: BoxDecoration(
            color: c.raised,
            borderRadius: BorderRadius.circular(SKRadius.xl),
            border: Border.all(color: c.hairline, width: 0.5),
            boxShadow: SKShadows.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(SKRadius.md),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: c.accent,
                ),
              ),
              const SizedBox(width: SKSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SKSpacing.x2),
              Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
