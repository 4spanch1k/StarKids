// GlassContainer — base Liquid Glass surface. Layering order:
//   ClipRRect (radius)
//     ├─ BackdropFilter (sigma = blur/2)
//     ├─ Container (linear-gradient tint)
//     ├─ Inner shine (top 1px highlight)
//     └─ Hairline border (0.5px)
// Drop-shadow lives OUTSIDE the clip so it isn't blurred.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? radius;
  final double blur;               // logical px; capped to SKBlur.max internally
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow> shadow;
  final bool drawBorder;
  final bool drawShine;
  final Color? tintOverride;       // override the resolved glassTint
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.radius,
    this.blur = SKBlur.base,
    this.padding,
    this.shadow = SKShadows.md,
    this.drawBorder = true,
    this.drawShine = true,
    this.tintOverride,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final r = radius ?? SKRadius.lg;
    final b = blur.clamp(0.0, SKBlur.max);

    final Widget surface = ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Stack(
        children: [
          // Keep BackdropFilter areas SMALL — never screen-sized here.
          if (b > 0)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: b / 2, sigmaY: b / 2),
                child: const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [tintOverride ?? c.glassTint, c.glassTint2],
                ),
              ),
            ),
          ),
          if (drawShine)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(height: 1, color: c.glassShine),
            ),
          if (drawBorder)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r),
                    border: Border.all(color: c.glassBorder, width: 0.5),
                  ),
                ),
              ),
            ),
          Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null
            ? surface
            : InkWell(
                borderRadius: BorderRadius.circular(r),
                onTap: onTap,
                child: surface,
              ),
      ),
    );
  }
}

/// Capsule variant — used for nav icons, branch selector, hero badges.
class GlassPill extends StatelessWidget {
  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const GlassPill({
    super.key,
    required this.child,
    this.height = SKSpacing.tapTarget,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: GlassContainer(
        radius: SKRadius.pill,
        blur: SKBlur.base,
        shadow: SKShadows.sm,
        padding: padding,
        onTap: onTap,
        child: Center(child: child),
      ),
    );
  }
}
