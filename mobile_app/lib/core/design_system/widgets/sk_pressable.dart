import 'package:flutter/material.dart';

class SkPressable extends StatefulWidget {
  const SkPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.scale = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final double scale;

  @override
  State<SkPressable> createState() => _SkPressableState();
}

class _SkPressableState extends State<SkPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;

    return AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        child: InkWell(
          borderRadius: widget.borderRadius,
          onTap: widget.onTap,
          onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          splashColor: Colors.white.withValues(alpha: 0.14),
          highlightColor: Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}
