// GlassCard — use only when content sits over imagery (hero badges, news).
// SolidCard is the default for forms, dense lists, and stat panels.

import 'package:flutter/material.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';
import 'glass_container.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? radius;
  final VoidCallback? onTap;
  final List<BoxShadow> shadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SKSpacing.x4),
    this.radius,
    this.onTap,
    this.shadow = SKShadows.md,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: radius ?? SKRadius.lg,
      padding: padding,
      shadow: shadow,
      onTap: onTap,
      child: child,
    );
  }
}

/// Non-glass content card — use this as the default for most screens.
class SolidCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? radius;
  final VoidCallback? onTap;
  final List<BoxShadow> shadow;

  const SolidCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SKSpacing.x4),
    this.radius,
    this.onTap,
    this.shadow = SKShadows.sm,
  });

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final r = radius ?? SKRadius.lg;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: c.hairline, width: 0.5),
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(r),
        child: InkWell(
          borderRadius: BorderRadius.circular(r),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
