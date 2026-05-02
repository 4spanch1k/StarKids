import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_icon_sizes.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';

enum TicketsEntryAction { myTickets, buyTicket }

Future<TicketsEntryAction?> showTicketsEntrySheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showStarKidsModalBottomSheet<TicketsEntryAction>(
    context: context,
    backgroundColor: isDark
        ? StarKidsDarkColors.surfaceElevated
        : StarKidsColors.surfacePrimary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const _TicketsEntrySheet(),
  );
}

class _TicketsEntrySheet extends StatelessWidget {
  const _TicketsEntrySheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            StarKidsSpacing.xl,
            StarKidsSpacing.md,
            StarKidsSpacing.xl,
            StarKidsSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? StarKidsDarkColors.borderDefault
                        : StarKidsColors.borderDefault,
                    borderRadius: BorderRadius.circular(StarKidsRadii.full),
                  ),
                ),
              ),
              const SizedBox(height: StarKidsSpacing.lg),
              Text('Билеты', style: textTheme.headlineSmall),
              const SizedBox(height: StarKidsSpacing.sm),
              Text(
                'Выберите, что хотите сделать сейчас.',
                style: textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? StarKidsDarkColors.textSecondary
                      : StarKidsColors.textSecondary,
                ),
              ),
              const SizedBox(height: StarKidsSpacing.lg),
              _TicketsEntryActionCard(
                key: const ValueKey('my-tickets-action'),
                icon: Icons.confirmation_num_rounded,
                title: 'Мои билеты',
                subtitle: 'История и активные билеты',
                onTap: () =>
                    Navigator.of(context).pop(TicketsEntryAction.myTickets),
              ),
              const SizedBox(height: StarKidsSpacing.md),
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
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? StarKidsDarkColors.surfacePrimary
        : StarKidsColors.surfacePrimary;
    final iconBg = isDark
        ? StarKidsDarkColors.glassSurface
        : StarKidsColors.surfaceSecondary;
    final borderColor = isDark
        ? StarKidsDarkColors.borderDefault
        : StarKidsColors.borderDefault;
    final accentColor =
        isDark ? StarKidsDarkColors.accentPink : StarKidsColors.brandPrimary;
    final secondaryText = isDark
        ? StarKidsDarkColors.textSecondary
        : StarKidsColors.textSecondary;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(StarKidsRadii.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        child: Container(
          padding: const EdgeInsets.all(StarKidsSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StarKidsRadii.xl),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(StarKidsRadii.lg),
                ),
                child: Icon(
                  icon,
                  size: StarKidsIconSizes.md,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: StarKidsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    const SizedBox(height: StarKidsSpacing.xs),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StarKidsSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
