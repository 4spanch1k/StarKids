import 'package:flutter/material.dart';

import '../foundations/sk_tokens.dart';

class SkCard extends StatefulWidget {
  const SkCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool elevated;

  @override
  State<SkCard> createState() => _SkCardState();
}

class _SkCardState extends State<SkCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? SK.darkBgElev : SK.bgElev,
          borderRadius: BorderRadius.circular(SK.rLg),
          border: Border.all(
            color: isDark ? SK.darkLine : SK.line,
          ),
          boxShadow: widget.elevated && !isDark ? SK.shadowMd : null,
        ),
        child: widget.onTap == null
            ? Padding(
                padding: widget.padding ?? const EdgeInsets.all(SK.s4),
                child: widget.child,
              )
            : Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(SK.rLg),
                child: InkWell(
                  onTap: widget.onTap,
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapUp: (_) => setState(() => _pressed = false),
                  onTapCancel: () => setState(() => _pressed = false),
                  borderRadius: BorderRadius.circular(SK.rLg),
                  child: Padding(
                    padding: widget.padding ?? const EdgeInsets.all(SK.s4),
                    child: widget.child,
                  ),
                ),
              ),
      ),
    );
  }
}
