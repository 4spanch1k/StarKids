import 'package:flutter/material.dart';

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
    final compact = MediaQuery.sizeOf(context).width < 380;

    return StarKidsReveal(
      delay: revealDelay,
      child: SolidCard(
        radius: SKRadius.xl,
        padding: EdgeInsets.all(compact ? SKSpacing.x3 : SKSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SKSpacing.x3,
                  vertical: SKSpacing.x2,
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
              const SizedBox(height: SKSpacing.x3),
            ],
            Text(
              title,
              style: compact ? textTheme.titleMedium : textTheme.titleLarge,
            ),
            const SizedBox(height: SKSpacing.x2),
            Text(
              body,
              style: compact ? textTheme.bodyMedium : textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
