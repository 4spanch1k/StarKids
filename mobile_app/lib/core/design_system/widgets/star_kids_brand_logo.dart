import 'dart:math' as math;

import 'package:flutter/material.dart';

const starKidsLogoAssetPath =
    'assets/images/645959303_17890733316429584_1469844678684572952_n.jpg';

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
              child: Image.asset(
                starKidsLogoAssetPath,
                width: resolvedLogoSize,
                height: resolvedLogoSize,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }
}
