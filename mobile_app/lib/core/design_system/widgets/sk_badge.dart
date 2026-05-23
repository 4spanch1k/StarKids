import 'package:flutter/material.dart';

import '../foundations/star_kids_spacing.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';

class SkBadge extends StatelessWidget {
  const SkBadge({
    super.key,
    required this.label,
    this.color,
    this.bgColor,
  });

  final String label;
  final Color? color;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.md,
        vertical: StarKidsSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor ?? c.accentSoft,
        borderRadius: BorderRadius.circular(SKRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color ?? c.textPrimary,
            ),
      ),
    );
  }
}
