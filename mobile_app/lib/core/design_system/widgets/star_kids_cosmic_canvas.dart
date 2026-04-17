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

    _drawBlob(canvas, Offset(size.width * 0.88, size.height * 0.07),
        size.width * 0.54, const Color(0x30FFCCE7));
    _drawBlob(canvas, Offset(size.width * 0.04, size.height * 0.30),
        size.width * 0.50, const Color(0x26D4BEFF));
    _drawBlob(canvas, Offset(size.width * 0.70, size.height * 0.52),
        size.width * 0.46, const Color(0x22FFD8BE));
    _drawBlob(canvas, Offset(size.width * 0.18, size.height * 0.74),
        size.width * 0.42, const Color(0x1ABEE8FF));
    _drawBlob(canvas, Offset(size.width * 0.52, size.height * 0.94),
        size.width * 0.38, const Color(0x24E8BEFF));

    _drawStarDust(canvas, size, dark: false);
  }

  void _paintDark(Canvas canvas, Size size) {
    // Base: deep cosmic indigo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0B0B1E),
    );

    // Violet nebula — top-right
    _drawBlob(canvas, Offset(size.width * 0.85, size.height * 0.10),
        size.width * 0.62, const Color(0x38A855F7));
    // Blue nebula — mid-left
    _drawBlob(canvas, Offset(size.width * 0.06, size.height * 0.38),
        size.width * 0.56, const Color(0x223B82F6));
    // Violet — bottom center
    _drawBlob(canvas, Offset(size.width * 0.55, size.height * 0.90),
        size.width * 0.52, const Color(0x2CA855F7));
    // Blue — lower-left accent
    _drawBlob(canvas, Offset(size.width * 0.20, size.height * 0.72),
        size.width * 0.38, const Color(0x183B82F6));

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
        dotPaint.color = Color.fromRGBO(160, 180, 255, alpha);
        canvas.drawCircle(Offset(x, y), r, dotPaint);
        dotPaint.color = const Color(0x44FFFFFF);
        canvas.drawCircle(Offset(x + r * 0.6, y - r * 0.6), r * 0.55, dotPaint);
      } else {
        dotPaint.color = Color.fromRGBO(235, 8, 118, alpha);
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
