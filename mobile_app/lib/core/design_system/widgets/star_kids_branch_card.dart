import 'package:flutter/material.dart';

import '../foundations/star_kids_colors.dart';
import '../foundations/star_kids_icon_sizes.dart';
import '../foundations/star_kids_radii.dart';
import '../foundations/star_kids_spacing.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryIconColor = isDark
        ? StarKidsDarkColors.textSecondary
        : StarKidsColors.textSecondary;

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
                            StarKidsColors.overlayImageTop,
                            StarKidsColors.overlayImageBottom,
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
                            color: isDark
                                ? StarKidsDarkColors.glassSurface
                                : StarKidsColors.surfacePrimary,
                            borderRadius: BorderRadius.circular(
                              StarKidsRadii.full,
                            ),
                          ),
                          child: Text(
                            tagLabel!,
                            style: textTheme.labelMedium?.copyWith(
                              color: StarKidsColors.brandPrimary,
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
                          color: secondaryIconColor,
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
                          color: secondaryIconColor,
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
