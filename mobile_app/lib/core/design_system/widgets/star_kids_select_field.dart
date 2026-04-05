import 'package:flutter/material.dart';

import '../foundations/star_kids_colors.dart';
import '../foundations/star_kids_icon_sizes.dart';
import '../foundations/star_kids_radii.dart';
import '../foundations/star_kids_spacing.dart';

class StarKidsSelectField extends StatelessWidget {
  const StarKidsSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.leadingIcon,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final textTheme = Theme.of(context).textTheme;
    final borderColor = hasError
        ? StarKidsColors.borderError
        : StarKidsColors.borderDefault;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: StarKidsSpacing.sm,
            bottom: StarKidsSpacing.sm,
          ),
          child: Text(label, style: textTheme.labelMedium),
        ),
        Material(
          color: enabled
              ? StarKidsColors.surfacePrimary
              : StarKidsColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(StarKidsRadii.md),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(StarKidsRadii.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: StarKidsSpacing.lg,
                vertical: StarKidsSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(StarKidsRadii.md),
                border: Border.all(
                  color: borderColor,
                  width: hasError ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (leadingIcon != null) ...[
                    Icon(
                      leadingIcon,
                      size: StarKidsIconSizes.sm,
                      color: StarKidsColors.textSecondary,
                    ),
                    const SizedBox(width: StarKidsSpacing.md),
                  ],
                  Expanded(
                    child: Text(
                      value ?? 'Select',
                      style: textTheme.bodyLarge?.copyWith(
                        color: value == null
                            ? StarKidsColors.textSecondary
                            : StarKidsColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: StarKidsIconSizes.md,
                    color: StarKidsColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (helperText != null || errorText != null) ...[
          const SizedBox(height: StarKidsSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: StarKidsSpacing.sm),
            child: Text(
              errorText ?? helperText!,
              style: textTheme.labelMedium?.copyWith(
                color: hasError
                    ? StarKidsColors.statusError
                    : StarKidsColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

