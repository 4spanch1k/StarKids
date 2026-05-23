import 'package:flutter/material.dart';

import '../sk_design_tokens.dart';
import '../sk_theme.dart';
import 'primary_button.dart';
import 'star_kids_media_image.dart';
import 'star_kids_motion.dart';

class StarKidsPromoCard extends StatelessWidget {
  const StarKidsPromoCard({
    super.key,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.badgeLabel,
    this.onTap,
    this.actionLabel = 'Посмотреть',
    this.revealDelay = Duration.zero,
  });

  final String title;
  final String description;
  final String imagePath;
  final String badgeLabel;
  final VoidCallback? onTap;
  final String actionLabel;
  final Duration revealDelay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;

    return StarKidsReveal(
      delay: revealDelay,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 19 / 10,
              child: StarKidsMediaImage(source: imagePath),
            ),
            Padding(
              padding: const EdgeInsets.all(SKSpacing.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      badgeLabel,
                      style: textTheme.labelMedium?.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: SKSpacing.x3),
                  Text(title, style: textTheme.titleLarge),
                  const SizedBox(height: SKSpacing.x2),
                  Text(description, style: textTheme.bodyMedium),
                  const SizedBox(height: SKSpacing.x4),
                  PrimaryButton(label: actionLabel, onPressed: onTap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
