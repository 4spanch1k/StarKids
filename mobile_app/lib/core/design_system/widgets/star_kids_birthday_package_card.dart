import 'package:flutter/material.dart';

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
    this.compact = false,
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
  final bool compact;

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
                child: StarKidsMediaImage(
                  source: imagePath,
                  fallbackSource: 'assets/images/birthday_hero.jpg',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(SKSpacing.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isFeatured && !compact)
                      Container(
                        margin: const EdgeInsets.only(
                          bottom: SKSpacing.x3,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: SKSpacing.x3,
                          vertical: SKSpacing.x2,
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
                          child: Text(
                            title,
                            maxLines: compact ? 1 : null,
                            overflow: compact ? TextOverflow.ellipsis : null,
                            style: textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: SKSpacing.x3),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 120),
                          padding: const EdgeInsets.symmetric(
                            horizontal: SKSpacing.x3,
                            vertical: SKSpacing.x2,
                          ),
                          decoration: BoxDecoration(
                            color: c.accentSoft,
                            borderRadius: BorderRadius.circular(SKRadius.pill),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              priceLabel,
                              maxLines: 1,
                              style: textTheme.labelMedium?.copyWith(
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SKSpacing.x1),
                    Text(guestLabel, style: textTheme.labelMedium),
                    if (normalizedDescription.isNotEmpty) ...[
                      const SizedBox(height: SKSpacing.x2),
                      Text(
                        normalizedDescription,
                        maxLines: compact ? 2 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                    if (!compact && normalizedHighlights.isNotEmpty) ...[
                      const SizedBox(height: SKSpacing.x3),
                      ...normalizedHighlights.map(
                        (highlight) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: SKSpacing.x1,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: c.cta,
                                ),
                              ),
                              const SizedBox(width: SKSpacing.x2),
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
                    const SizedBox(height: SKSpacing.x4),
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
