// GlassFloatingButton — solid-blue capsule CTA floating above content.
// Used for "Организовать день рождения" on the Birthdays screen.
// Wraps PrimaryButton; default margin places it above the bottom-nav pill.

import 'package:flutter/material.dart';
import '../sk_design_tokens.dart';
import 'primary_button.dart';

class GlassFloatingButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry margin;

  const GlassFloatingButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.margin = const EdgeInsets.fromLTRB(
      SKSpacing.gutter, 0, SKSpacing.gutter, 90,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: PrimaryButton(
        label: label,
        icon: icon,
        onPressed: onPressed,
        size: SKButtonSize.lg,
      ),
    );
  }
}
