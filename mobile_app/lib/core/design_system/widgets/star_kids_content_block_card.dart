import 'package:flutter/material.dart';

import '../foundations/star_kids_spacing.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';
import 'glass_card.dart';
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
    final c = SKTheme.of(context).colors;

    return StarKidsReveal(
      delay: revealDelay,
      child: SolidCard(
        radius: SKRadius.xl,
        padding: const EdgeInsets.all(StarKidsSpacing.lg),
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
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(SKRadius.pill),
                ),
                child: Text(
                  label!,
                  style: textTheme.labelMedium?.copyWith(color: c.cta),
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
