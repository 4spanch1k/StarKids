// GlassAppBar — frosted-glass top bar with backdrop-blur strip.
// Children: leading (44×44 glass pill) · title · trailing.
// Implements PreferredSizeWidget so it can be used as Scaffold.appBar.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const GlassAppBar({
    super.key,
    this.leading,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      SKSpacing.gutter,
      SKSpacing.x2,
      SKSpacing.gutter,
      SKSpacing.x2,
    ),
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x14211E19),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.glassTint, c.glassTint2],
              ),
              border: Border(
                bottom: BorderSide(color: c.glassBorder, width: 1.0),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: padding,
                child: Row(
                  children: [
                    if (leading != null) leading!,
                    if (leading != null) const SizedBox(width: SKSpacing.x2),
                    Expanded(child: title ?? const SizedBox.shrink()),
                    if (trailing != null) const SizedBox(width: SKSpacing.x2),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular glass icon button — 44×44, used in app bars.
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool dot;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.dot = false,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    final btn = Tooltip(
      message: widget.tooltip ?? '',
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: SKSpacing.tapTarget,
              height: SKSpacing.tapTarget,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.glassTint,
                border: Border.all(color: c.glassBorder, width: 1.0),
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onPressed,
                  onTapDown: widget.onPressed == null
                      ? null
                      : (_) => setState(() => _pressed = true),
                  onTapUp: (_) => setState(() => _pressed = false),
                  onTapCancel: () => setState(() => _pressed = false),
                  child: Center(
                    child: Icon(widget.icon, size: 20, color: c.textPrimary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.dot) return btn;
    return Stack(clipBehavior: Clip.none, children: [
      btn,
      Positioned(
        right: 10,
        top: 10,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: c.accent,
            shape: BoxShape.circle,
            border: Border.all(color: c.elevated, width: 2),
          ),
        ),
      ),
    ]);
  }
}
