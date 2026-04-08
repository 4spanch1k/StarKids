import 'package:flutter/material.dart';

import '../foundations/star_kids_colors.dart';
import '../foundations/star_kids_icon_sizes.dart';
import '../foundations/star_kids_radii.dart';
import '../foundations/star_kids_spacing.dart';
import 'star_kids_media_image.dart';
import 'star_kids_button.dart';

class StarKidsBirthdayPackageCard extends StatelessWidget {
  const StarKidsBirthdayPackageCard({
    super.key,
    required this.title,
    required this.priceLabel,
    required this.guestLabel,
    required this.description,
    required this.highlights,
    required this.imagePath,
    this.isFeatured = false,
    this.onTap,
    this.onActionTap,
  });

  final String title;
  final String priceLabel;
  final String guestLabel;
  final String description;
  final List<String> highlights;
  final String imagePath;
  final bool isFeatured;
  final VoidCallback? onTap;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final normalizedDescription = description.trim();
    final normalizedHighlights = highlights
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        side: BorderSide(
          color: isFeatured
              ? StarKidsColors.brandPrimary
              : StarKidsColors.borderDefault,
        ),
      ),
      child: InkWell(
        onTap: onTap,
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
                  if (isFeatured)
                    Container(
                      margin: const EdgeInsets.only(bottom: StarKidsSpacing.md),
                      padding: const EdgeInsets.symmetric(
                        horizontal: StarKidsSpacing.md,
                        vertical: StarKidsSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: StarKidsColors.surfaceTertiary,
                        borderRadius: BorderRadius.circular(
                          StarKidsRadii.full,
                        ),
                      ),
                      child: Text(
                        'Хит продаж',
                        style: textTheme.labelMedium?.copyWith(
                          color: StarKidsColors.brandPrimary,
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(title, style: textTheme.titleLarge),
                      ),
                      const SizedBox(width: StarKidsSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: StarKidsSpacing.md,
                          vertical: StarKidsSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: StarKidsColors.brandHighlight,
                          borderRadius: BorderRadius.circular(
                            StarKidsRadii.full,
                          ),
                        ),
                        child: Text(
                          priceLabel,
                          style: textTheme.labelMedium?.copyWith(
                            color: StarKidsColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: StarKidsSpacing.xs),
                  Text(guestLabel, style: textTheme.labelMedium),
                  if (normalizedDescription.isNotEmpty) ...[
                    const SizedBox(height: StarKidsSpacing.sm),
                    Text(
                      normalizedDescription,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                  if (normalizedHighlights.isNotEmpty) ...[
                    const SizedBox(height: StarKidsSpacing.md),
                    ...normalizedHighlights.map(
                      (highlight) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: StarKidsSpacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.star_rounded,
                                size: StarKidsIconSizes.xs,
                                color: StarKidsColors.brandPrimary,
                              ),
                            ),
                            const SizedBox(width: StarKidsSpacing.sm),
                            Expanded(
                              child: Text(
                                highlight,
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: StarKidsSpacing.lg),
                  StarKidsButton.primary(
                    label: 'Оставить заявку',
                    onPressed: onActionTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
