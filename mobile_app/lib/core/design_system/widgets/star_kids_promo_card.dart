import 'package:flutter/material.dart';

import '../foundations/star_kids_colors.dart';
import '../foundations/star_kids_radii.dart';
import '../foundations/star_kids_spacing.dart';
import 'star_kids_media_image.dart';
import 'star_kids_button.dart';

class StarKidsPromoCard extends StatelessWidget {
  const StarKidsPromoCard({
    super.key,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.badgeLabel,
    this.onTap,
    this.actionLabel = 'Посмотреть',
  });

  final String title;
  final String description;
  final String imagePath;
  final String badgeLabel;
  final VoidCallback? onTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 19 / 10,
            child: StarKidsMediaImage(source: imagePath),
          ),
          Padding(
            padding: const EdgeInsets.all(StarKidsSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StarKidsSpacing.md,
                    vertical: StarKidsSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: StarKidsColors.brandHighlight,
                    borderRadius: BorderRadius.circular(StarKidsRadii.full),
                  ),
                  child: Text(
                    badgeLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: StarKidsColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: StarKidsSpacing.md),
                Text(title, style: textTheme.titleLarge),
                const SizedBox(height: StarKidsSpacing.sm),
                Text(description, style: textTheme.bodyMedium),
                const SizedBox(height: StarKidsSpacing.lg),
                StarKidsButton.primary(
                  label: actionLabel,
                  onPressed: onTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
