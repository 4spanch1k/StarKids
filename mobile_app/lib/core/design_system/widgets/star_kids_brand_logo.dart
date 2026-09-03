import 'dart:math' as math;

import 'package:flutter/material.dart';

class StarKidsBrandLogo extends StatelessWidget {
  const StarKidsBrandLogo({
    super.key,
    this.logoSize = 96,
    this.maxRelativeSize = 0.32,
    this.padding = 6,
  });

  final double logoSize;
  final double maxRelativeSize;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = constraints.biggest.shortestSide;
        final resolvedLogoSize = shortestSide.isFinite
            ? math.min(logoSize, shortestSide * maxRelativeSize)
            : logoSize;

        return DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: ClipOval(
              child: SizedBox(
                width: resolvedLogoSize,
                height: resolvedLogoSize,
                child: Center(
                  child: Text(
                    'Boom Bala',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF1D1720),
                      fontSize: resolvedLogoSize * 0.19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
