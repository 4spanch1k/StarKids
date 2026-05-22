// SKBadge — pill label for statuses, counts, tags.
// SKChip — tappable filter chip; active state inverts to solid textPrimary.

import 'package:flutter/material.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';

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
    return Material(
      color: active ? c.textPrimary : c.elevated.withValues(alpha: 0.85),
      shape: StadiumBorder(
        side: BorderSide(
          color: active ? Colors.transparent : c.hairline,
          width: 0.5,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          constraints: const BoxConstraints(
            minHeight: SKSpacing.tapTarget - 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: active ? Colors.white : c.textPrimary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: SKTextStyles.small.copyWith(
                  color: active ? Colors.white : c.textPrimary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
