import 'package:flutter/material.dart';

import 'star_kids_button.dart';

enum SkButtonStyle { primary, accent, soft, ghost }

class SkButton extends StatelessWidget {
  const SkButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.style = SkButtonStyle.primary,
    this.block = false,
    this.iconRight = false,
  });

  final String label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final SkButtonStyle style;
  final bool block;
  final bool iconRight;

  @override
  Widget build(BuildContext context) {
    final iconData = icon is Icon ? (icon as Icon).icon : null;
    final variant = switch (style) {
      SkButtonStyle.primary || SkButtonStyle.accent =>
        StarKidsButtonVariant.primary,
      SkButtonStyle.soft => StarKidsButtonVariant.secondary,
      SkButtonStyle.ghost => StarKidsButtonVariant.ghost,
    };

    return StarKidsButton(
      label: label,
      onPressed: onPressed,
      icon: iconData,
      variant: variant,
      expand: block,
    );
  }
}
