import 'package:flutter/material.dart';

import '../foundations/star_kids_colors.dart';
import '../foundations/star_kids_radii.dart';
import '../foundations/star_kids_spacing.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.md,
        vertical: StarKidsSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor ??
            (isDark
                ? StarKidsDarkColors.glassSurface
                : StarKidsColors.warmCoral),
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color ??
                  (isDark
                      ? StarKidsDarkColors.textPrimary
                      : StarKidsColors.textPrimary),
            ),
      ),
    );
  }
}
