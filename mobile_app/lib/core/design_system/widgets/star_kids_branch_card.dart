import 'package:flutter/material.dart';

import '../foundations/star_kids_colors.dart';
import '../foundations/star_kids_icon_sizes.dart';
import '../foundations/star_kids_radii.dart';
import '../foundations/star_kids_spacing.dart';

class StarKidsBranchCard extends StatelessWidget {
  const StarKidsBranchCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.address,
    required this.workingHours,
    this.onTap,
    this.tagLabel,
  });

  final String imagePath;
  final String title;
  final String address;
  final String workingHours;
  final VoidCallback? onTap;
  final String? tagLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
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
                  Image.asset(imagePath, fit: BoxFit.cover),
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
                          color: StarKidsColors.surfacePrimary,
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
                      const Icon(
                        Icons.schedule_rounded,
                        size: StarKidsIconSizes.sm,
                        color: StarKidsColors.textSecondary,
                      ),
                      const SizedBox(width: StarKidsSpacing.sm),
                      Expanded(
                        child: Text(
                          workingHours,
                          style: textTheme.labelMedium,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: StarKidsIconSizes.xs,
                        color: StarKidsColors.textSecondary,
                      ),
                    ],
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
