import 'package:flutter/material.dart';

import '../foundations/star_kids_colors.dart';
import '../foundations/star_kids_radii.dart';
import '../foundations/star_kids_spacing.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StarKidsReveal(
      delay: revealDelay,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? StarKidsDarkColors.glassSurface
              : StarKidsColors.surfacePrimary,
          borderRadius: BorderRadius.circular(StarKidsRadii.xl),
          border: Border.all(
            color: isDark
                ? StarKidsDarkColors.borderDefault
                : StarKidsColors.borderDefault,
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: StarKidsSpacing.lg,
              vertical: StarKidsSpacing.sm,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              StarKidsSpacing.lg,
              0,
              StarKidsSpacing.lg,
              StarKidsSpacing.lg,
            ),
            iconColor: StarKidsColors.brandPrimary,
            collapsedIconColor: isDark
                ? StarKidsDarkColors.textSecondary
                : StarKidsColors.textSecondary,
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
    );
  }
}
