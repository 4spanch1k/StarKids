import 'package:flutter/material.dart';

import '../foundations/star_kids_icon_sizes.dart';
import '../foundations/star_kids_spacing.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';
import 'star_kids_media_image.dart';
import 'star_kids_motion.dart';

class StarKidsBranchCard extends StatelessWidget {
  const StarKidsBranchCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.address,
    required this.workingHours,
    this.onTap,
    this.tagLabel,
    this.revealDelay = Duration.zero,
  });

  final String imagePath;
  final String title;
  final String address;
  final String workingHours;
  final VoidCallback? onTap;
  final String? tagLabel;
  final Duration revealDelay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;

    return StarKidsReveal(
      delay: revealDelay,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 19 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    StarKidsMediaImage(source: imagePath),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00000000),
                            Color(0x6B000000),
                          ],
                        ),
                      ),
                    ),
                    if (tagLabel != null)
                      Positioned(
                        top: StarKidsSpacing.lg,
                        left: StarKidsSpacing.lg,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: StarKidsSpacing.md,
                            vertical: StarKidsSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: c.elevated,
                            borderRadius: BorderRadius.circular(SKRadius.pill),
                          ),
                          child: Text(
                            tagLabel!,
                            style: textTheme.labelMedium?.copyWith(
                              color: c.cta,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(StarKidsSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleLarge),
                    const SizedBox(height: StarKidsSpacing.sm),
                    Text(address, style: textTheme.bodyMedium),
                    const SizedBox(height: StarKidsSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: StarKidsIconSizes.sm,
                          color: c.textSecondary,
                        ),
                        const SizedBox(width: StarKidsSpacing.sm),
                        Expanded(
                          child: Text(
                            workingHours,
                            style: textTheme.labelMedium,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: StarKidsIconSizes.xs,
                          color: c.textSecondary,
                        ),
                      ],
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
