import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps [child] with a soft pastel nebula background.
/// Uses a single [CustomPaint] pass — no blur, no compositing overhead.
class StarKidsCosmicCanvas extends StatelessWidget {
  const StarKidsCosmicCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _CosmicCanvasPainter(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _CosmicCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base gradient: warm pink top-left → lavender center → sky bottom-right
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF4FA),
          Color(0xFFF5F0FF),
          Color(0xFFF0F6FF),
        ],
        stops: [0.0, 0.52, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Soft nebula blobs — positioned so they look organic across all screen sizes
    _drawBlob(
        canvas, size, Offset(size.width * 0.88, size.height * 0.07),
        size.width * 0.54, const Color(0x30FFCCE7)); // top-right pink
    _drawBlob(
        canvas, size, Offset(size.width * 0.04, size.height * 0.30),
        size.width * 0.50, const Color(0x26D4BEFF)); // mid-left lavender
    _drawBlob(
        canvas, size, Offset(size.width * 0.70, size.height * 0.52),
        size.width * 0.46, const Color(0x22FFD8BE)); // center-right peach
    _drawBlob(
        canvas, size, Offset(size.width * 0.18, size.height * 0.74),
        size.width * 0.42, const Color(0x1ABEE8FF)); // bottom-left sky
    _drawBlob(
        canvas, size, Offset(size.width * 0.52, size.height * 0.94),
        size.width * 0.38, const Color(0x24E8BEFF)); // bottom-center lavender

    // Star dust — deterministic via seeded Random so shouldRepaint = false
    _drawStarDust(canvas, size);
  }

  void _drawBlob(
      Canvas canvas, Size size, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, const Color(0x00000000)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawStarDust(Canvas canvas, Size size) {
    final rng = math.Random(0xDEADBEEF);
    final dotPaint = Paint();

    for (int i = 0; i < 26; i++) {
      final x = size.width * (0.04 + rng.nextDouble() * 0.92);
      final y = size.height * (0.02 + rng.nextDouble() * 0.96);
      final alpha = 0.15 + rng.nextDouble() * 0.35;
      final r = 0.8 + rng.nextDouble() * 0.8;

      // Pink star core
      dotPaint.color = Color.fromRGBO(235, 8, 118, alpha);
      canvas.drawCircle(Offset(x, y), r, dotPaint);

      // White highlight offset
      dotPaint.color = const Color(0x55FFFFFF);
      canvas.drawCircle(Offset(x + r * 0.6, y - r * 0.6), r * 0.55, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_CosmicCanvasPainter oldDelegate) => false;
}
