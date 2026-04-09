import 'package:flutter/material.dart';

import '../foundations/star_kids_colors.dart';
import '../foundations/star_kids_icon_sizes.dart';
import '../foundations/star_kids_radii.dart';
import '../foundations/star_kids_shadows.dart';
import '../foundations/star_kids_spacing.dart';

enum StarKidsButtonVariant {
  primary,
  secondary,
  ghost,
}

class StarKidsButton extends StatelessWidget {
  const StarKidsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = StarKidsButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final StarKidsButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  const StarKidsButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = StarKidsButtonVariant.primary;

  const StarKidsButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = StarKidsButtonVariant.secondary;

  const StarKidsButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  }) : variant = StarKidsButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    final content = _ButtonContent(
      label: label,
      icon: icon,
      isLoading: isLoading,
      foregroundColor: _foregroundColor(isDisabled),
    );

    final button = switch (variant) {
      StarKidsButtonVariant.primary => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StarKidsRadii.full),
            boxShadow: isDisabled ? const [] : StarKidsShadows.depth1,
          ),
          child: FilledButton(
            onPressed: isDisabled ? null : onPressed,
            child: content,
          ),
        ),
      StarKidsButtonVariant.secondary => OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          child: content,
        ),
      StarKidsButtonVariant.ghost => TextButton(
          onPressed: isDisabled ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: _foregroundColor(isDisabled),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StarKidsRadii.full),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: StarKidsSpacing.lg,
              vertical: StarKidsSpacing.md,
            ),
          ),
          child: content,
        ),
    };

    if (!expand || variant == StarKidsButtonVariant.ghost) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }

  Color _foregroundColor(bool isDisabled) {
    if (isDisabled) {
      return StarKidsColors.actionDisabledFg;
    }

    return switch (variant) {
      StarKidsButtonVariant.primary => StarKidsColors.textInverse,
      StarKidsButtonVariant.secondary => StarKidsColors.textPrimary,
      StarKidsButtonVariant.ghost => StarKidsColors.brandPrimary,
    };
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.foregroundColor,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final text = Text(label);

    if (isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: StarKidsIconSizes.sm,
            height: StarKidsIconSizes.sm,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          ),
          const SizedBox(width: StarKidsSpacing.sm),
          text,
        ],
      );
    }

    if (icon == null) {
      return text;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: StarKidsIconSizes.sm),
        const SizedBox(width: StarKidsSpacing.sm),
        text,
      ],
    );
  }
}
