import 'package:flutter/material.dart';

import '../foundations/sk_tokens.dart';

enum SkButtonStyle { primary, accent, soft, ghost }

class SkButton extends StatefulWidget {
  const SkButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.style = SkButtonStyle.primary,
    this.block = false,
    this.iconRight = false,
  });

  final String label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final SkButtonStyle style;
  final bool block;
  final bool iconRight;

  @override
  State<SkButton> createState() => _SkButtonState();
}

class _SkButtonState extends State<SkButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = widget.onPressed == null;
    final (bg, fg, border, shadow) = switch (widget.style) {
      SkButtonStyle.primary => (
          isDark ? SK.accent : SK.accent2,
          Colors.white,
          null,
          isDisabled ? null : SK.shadowMd,
        ),
      SkButtonStyle.accent => (
          SK.accent,
          Colors.white,
          null,
          isDisabled
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x47FF5A5F),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
      SkButtonStyle.soft => (
          isDark ? SK.darkBgSoft : SK.bgSoft,
          isDark ? SK.darkInk : SK.ink,
          null,
          null,
        ),
      SkButtonStyle.ghost => (
          Colors.transparent,
          isDark ? SK.darkInk : SK.ink,
          Border.all(color: isDark ? SK.darkLineStrong : SK.lineStrong),
          null,
        ),
    };

    final child = AnimatedScale(
      scale: _pressed ? 0.965 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.55 : 1,
        duration: const Duration(milliseconds: 160),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(SK.rPill),
          child: InkWell(
            borderRadius: BorderRadius.circular(SK.rPill),
            onTap: widget.onPressed,
            onTapDown:
                isDisabled ? null : (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            splashColor: Colors.white.withValues(alpha: 0.15),
            highlightColor: Colors.transparent,
            child: Container(
              width: widget.block ? double.infinity : null,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SK.rPill),
                border: border,
                boxShadow: shadow,
              ),
              child: Row(
                mainAxisSize:
                    widget.block ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null && !widget.iconRight) ...[
                    IconTheme(
                      data: IconThemeData(color: fg, size: 18),
                      child: widget.icon!,
                    ),
                    const SizedBox(width: SK.s2),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: fg,
                        fontFamily: 'Geist',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        letterSpacing: -0.16,
                      ),
                    ),
                  ),
                  if (widget.icon != null && widget.iconRight) ...[
                    const SizedBox(width: SK.s2),
                    IconTheme(
                      data: IconThemeData(color: fg, size: 18),
                      child: widget.icon!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return widget.block
        ? SizedBox(width: double.infinity, child: child)
        : child;
  }
}
