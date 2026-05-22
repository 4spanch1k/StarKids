// GlassAppBar — sticky top bar with backdrop-blur strip.
// Children: leading (44×44 pill) · title · trailing.
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
      SKSpacing.gutter, SKSpacing.x2, SKSpacing.gutter, SKSpacing.x2,
    ),
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: SKBlur.subtle / 2,
          sigmaY: SKBlur.subtle / 2,
        ),
        child: Container(
          color: c.bg.withValues(alpha: SKOpacity.glassPanel),
          padding: padding,
          child: SafeArea(
            bottom: false,
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
    );
  }
}

/// Round icon button — 44×44 white pill with hairline, used in app bars.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool dot;   // shows a notification dot

  const GlassIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final btn = Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: c.elevated,
        shape: const StadiumBorder(),
        elevation: 0,
        shadowColor: const Color(0x10211E19),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: SKSpacing.tapTarget,
            height: SKSpacing.tapTarget,
            child: Icon(icon, size: 20, color: c.textPrimary),
          ),
        ),
      ),
    );
    if (!dot) return btn;
    return Stack(clipBehavior: Clip.none, children: [
      btn,
      Positioned(
        right: 10, top: 10,
        child: Container(
          width: 8, height: 8,
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
