// SKBadge — pill label for statuses, counts, tags.
// SKChip — tappable filter chip; inactive = glass-look; active = solid textPrimary.
//   AnimatedContainer transitions fill + border. SkPressable for tap scale.

import 'package:flutter/material.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';
import 'sk_pressable.dart';

enum SKTone { accent, cta, success, warning, danger, neutral }

class SKBadge extends StatelessWidget {
  final String label;
  final SKTone tone;
  final bool small;

  const SKBadge({
    super.key,
    required this.label,
    this.tone = SKTone.accent,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final (bg, fg) = switch (tone) {
      SKTone.accent  => (c.accentSoft,  c.accent),
      SKTone.cta     => (c.ctaSoft,     c.cta),
      SKTone.success => (c.successSoft, c.success),
      SKTone.warning => (c.warningSoft, c.warning),
      SKTone.danger  => (c.dangerSoft,  c.danger),
      SKTone.neutral => (c.bg,          c.textSecondary),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SKRadius.pill),
      ),
      child: Text(
        label,
        style: SKTextStyles.micro.copyWith(
          color: fg,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class SKChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback? onTap;

  const SKChip({
    super.key,
    required this.label,
    this.icon,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    // Glass look for inactive: warm translucent tint + pearl border.
    // Active: solid textPrimary (opaque, readable).
    final bgColor = active ? c.textPrimary : c.glassTint;
    final borderColor = active ? Colors.transparent : c.glassBorder;
    final iconColor = active ? Colors.white : c.textPrimary;
    final textColor = active ? Colors.white : c.textPrimary;
    final fontWeight = active ? FontWeight.w600 : FontWeight.w500;

    return SkPressable(
      onTap: onTap,
      scale: 0.94,
      borderRadius: BorderRadius.circular(SKRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: const BoxConstraints(minHeight: SKSpacing.tapTarget - 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(SKRadius.pill),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 6),
            ],
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              style: SKTextStyles.small.copyWith(
                color: textColor,
                fontWeight: fontWeight,
                fontSize: 13,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
