import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps [child] with a soft nebula background — light or dark based on theme brightness.
/// Uses a single [CustomPaint] pass — no blur, no compositing overhead.
class StarKidsCosmicCanvas extends StatelessWidget {
  const StarKidsCosmicCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _CosmicCanvasPainter(isDark: isDark),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _CosmicCanvasPainter extends CustomPainter {
  const _CosmicCanvasPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) {
      _paintDark(canvas, size);
    } else {
      _paintLight(canvas, size);
    }
  }

  void _paintLight(Canvas canvas, Size size) {
    // Warm beige background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFFBF7F4),
    );

    // Soft coral blob — top-right
    _drawBlob(canvas, Offset(size.width * 0.88, size.height * 0.07),
        size.width * 0.58, const Color(0x14FF5A5F));
    // Soft plum blob — bottom-left
    _drawBlob(canvas, Offset(size.width * 0.04, size.height * 0.78),
        size.width * 0.54, const Color(0x0EE5D4F2));
    // Warm sun accent — mid
    _drawBlob(canvas, Offset(size.width * 0.60, size.height * 0.50),
        size.width * 0.40, const Color(0x0AFFC857));
  }

  void _paintDark(Canvas canvas, Size size) {
    // Base: warm dark background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0F0D0C),
    );

    // Coral glow — top-right
    _drawBlob(canvas, Offset(size.width * 0.85, size.height * 0.10),
        size.width * 0.62, const Color(0x2CFF5A5F));
    // Sky glow — mid-left
    _drawBlob(canvas, Offset(size.width * 0.06, size.height * 0.38),
        size.width * 0.56, const Color(0x22C7DDEF));
    // Plum — bottom center
    _drawBlob(canvas, Offset(size.width * 0.55, size.height * 0.90),
        size.width * 0.52, const Color(0x24E5D4F2));
    // Mint — lower-left accent
    _drawBlob(canvas, Offset(size.width * 0.20, size.height * 0.72),
        size.width * 0.38, const Color(0x18B6E3C8));

    _drawStarDust(canvas, size, dark: true);
  }

  void _drawBlob(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, const Color(0x00000000)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawStarDust(Canvas canvas, Size size, {required bool dark}) {
    final rng = math.Random(0xDEADBEEF);
    final dotPaint = Paint();

    for (int i = 0; i < 26; i++) {
      final x = size.width * (0.04 + rng.nextDouble() * 0.92);
      final y = size.height * (0.02 + rng.nextDouble() * 0.96);
      final alpha = dark
          ? (0.30 + rng.nextDouble() * 0.45)
          : (0.15 + rng.nextDouble() * 0.35);
      final r = 0.8 + rng.nextDouble() * 0.8;

      if (dark) {
        dotPaint.color = Color.fromRGBO(244, 239, 234, alpha);
        canvas.drawCircle(Offset(x, y), r, dotPaint);
        dotPaint.color = const Color(0x44FFFFFF);
        canvas.drawCircle(Offset(x + r * 0.6, y - r * 0.6), r * 0.55, dotPaint);
      } else {
        dotPaint.color = Color.fromRGBO(255, 90, 95, alpha);
        canvas.drawCircle(Offset(x, y), r, dotPaint);
        dotPaint.color = const Color(0x55FFFFFF);
        canvas.drawCircle(Offset(x + r * 0.6, y - r * 0.6), r * 0.55, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_CosmicCanvasPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
