import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';

class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.lg),
        border: Border.all(color: c.hairline, width: 0.5),
        boxShadow: SKShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleLarge,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: StarKidsSpacing.xs),
            Text(
              subtitle!,
              style: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          ],
          const SizedBox(height: StarKidsSpacing.lg),
          child,
        ],
      ),
    );
  }
}
