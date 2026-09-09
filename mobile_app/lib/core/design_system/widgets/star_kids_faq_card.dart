import 'package:flutter/material.dart';

import '../sk_design_tokens.dart';
import '../sk_theme.dart';
import 'star_kids_motion.dart';

class StarKidsFaqCard extends StatelessWidget {
  const StarKidsFaqCard({
    super.key,
    required this.question,
    required this.answer,
    this.revealDelay = Duration.zero,
  });

  final String question;
  final String answer;
  final Duration revealDelay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;

    return StarKidsReveal(
      delay: revealDelay,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.elevated,
          borderRadius: BorderRadius.circular(SKRadius.xl),
          border: Border.all(color: c.hairline, width: 0.5),
          boxShadow: SKShadows.sm,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SKRadius.xl),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: SKSpacing.x4,
                vertical: SKSpacing.x2,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                SKSpacing.x4,
                0,
                SKSpacing.x4,
                SKSpacing.x4,
              ),
              iconColor: c.cta,
              collapsedIconColor: c.textSecondary,
              title: Text(question, style: textTheme.titleMedium),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(answer, style: textTheme.bodyLarge),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
