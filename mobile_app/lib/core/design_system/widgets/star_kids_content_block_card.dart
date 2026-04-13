import 'package:flutter/material.dart';

import '../foundations/star_kids_colors.dart';
import '../foundations/star_kids_radii.dart';
import '../foundations/star_kids_spacing.dart';
import 'star_kids_motion.dart';

class StarKidsContentBlockCard extends StatelessWidget {
  const StarKidsContentBlockCard({
    super.key,
    required this.title,
    required this.body,
    this.label,
    this.revealDelay = Duration.zero,
  });

  final String title;
  final String body;
  final String? label;
  final Duration revealDelay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return StarKidsReveal(
      delay: revealDelay,
      child: Container(
        padding: const EdgeInsets.all(StarKidsSpacing.lg),
        decoration: BoxDecoration(
          color: StarKidsColors.surfacePrimary,
          borderRadius: BorderRadius.circular(StarKidsRadii.xl),
          border: Border.all(color: StarKidsColors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: StarKidsSpacing.md,
                  vertical: StarKidsSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: StarKidsColors.surfaceTertiary,
                  borderRadius: BorderRadius.circular(StarKidsRadii.full),
                ),
                child: Text(
                  label!,
                  style: textTheme.labelMedium?.copyWith(
                    color: StarKidsColors.brandPrimary,
                  ),
                ),
              ),
              const SizedBox(height: StarKidsSpacing.md),
            ],
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: StarKidsSpacing.sm),
            Text(body, style: textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
