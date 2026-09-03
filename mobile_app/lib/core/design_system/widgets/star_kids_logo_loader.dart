import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../sk_theme.dart';
import 'star_kids_brand_logo.dart';

class StarKidsLogoLoader extends StatelessWidget {
  const StarKidsLogoLoader({
    super.key,
    this.logoSize = 128,
    this.strokeWidth = 6,
  });

  final double logoSize;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = constraints.biggest.shortestSide;
        final resolvedLogoSize = shortestSide.isFinite
            ? math.min(logoSize, shortestSide * 0.68)
            : logoSize;
        final ringSize = resolvedLogoSize + 28;

        return SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: ringSize,
                child: CircularProgressIndicator(
                  strokeWidth: strokeWidth,
                  backgroundColor: c.hairline,
                  valueColor: AlwaysStoppedAnimation<Color>(c.cta),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.elevated,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: SizedBox.square(
                  dimension: resolvedLogoSize + 12,
                  child: StarKidsBrandLogo(
                    logoSize: resolvedLogoSize,
                    maxRelativeSize: 1,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.78),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
