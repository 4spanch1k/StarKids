import 'package:flutter/material.dart';

import '../foundations/star_kids_icon_sizes.dart';
import '../foundations/star_kids_spacing.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';
import 'primary_button.dart';
import 'star_kids_media_image.dart';
import 'star_kids_motion.dart';

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
    this.revealDelay = Duration.zero,
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
  final Duration revealDelay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;
    final normalizedDescription = description.trim();
    final normalizedHighlights = highlights
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return StarKidsReveal(
      delay: revealDelay,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SKRadius.xl),
          side: BorderSide(
            color: isFeatured ? c.cta : c.hairline,
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
                        margin: const EdgeInsets.only(
                          bottom: StarKidsSpacing.md,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: StarKidsSpacing.md,
                          vertical: StarKidsSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: c.accentSoft,
                          borderRadius: BorderRadius.circular(SKRadius.pill),
                        ),
                        child: Text(
                          'Хит продаж',
                          style: textTheme.labelMedium?.copyWith(
                            color: c.cta,
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
                            color: c.accentSoft,
                            borderRadius: BorderRadius.circular(SKRadius.pill),
                          ),
                          child: Text(
                            priceLabel,
                            style: textTheme.labelMedium?.copyWith(
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: StarKidsSpacing.xs),
                    Text(guestLabel, style: textTheme.labelMedium),
                    if (normalizedDescription.isNotEmpty) ...[
                      const SizedBox(height: StarKidsSpacing.sm),
                      Text(normalizedDescription, style: textTheme.bodyMedium),
                    ],
                    if (normalizedHighlights.isNotEmpty) ...[
                      const SizedBox(height: StarKidsSpacing.md),
                      ...normalizedHighlights.map(
                        (highlight) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: StarKidsSpacing.xs,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: StarKidsIconSizes.xs,
                                  color: c.cta,
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
                    PrimaryButton(
                      label: 'Оставить заявку',
                      onPressed: onActionTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
