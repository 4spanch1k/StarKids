// PrimaryButton — ALWAYS solid #2563EB. Never glass or transparent.
// Disabled: muted gray + reduced opacity + no shadow.
// SecondaryButton: outline pill for secondary actions.
// DestructiveButton: danger-soft background, for destructive actions.

import 'package:flutter/material.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';

enum SKButtonSize { sm, md, lg }

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final SKButtonSize size;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.fullWidth = true,
    this.size = SKButtonSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final disabled = onPressed == null;

    final h = switch (size) {
      SKButtonSize.sm => 40.0,
      SKButtonSize.lg => 56.0,
      _               => 50.0,
    };
    final fs = switch (size) {
      SKButtonSize.sm => 14.0,
      SKButtonSize.lg => 17.0,
      _               => 15.0,
    };

    final btn = AnimatedContainer(
      duration: SKMotion.fast,
      curve: SKMotion.curve,
      height: h,
      decoration: BoxDecoration(
        color: disabled ? c.textDisabled : c.cta,
        borderRadius: BorderRadius.circular(SKRadius.pill),
        boxShadow: disabled ? const [] : SKShadows.ctaBlue,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SKRadius.pill),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: SKTypography.body,
                      fontSize: fs,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: 18, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Opacity(
      opacity: disabled ? 0.65 : 1,
      child: fullWidth ? SizedBox(width: double.infinity, child: btn) : btn,
    );
  }
}

/// Outline pill — for "Все новости", "Изменить филиал", "Добавить".
class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool fullWidth;

  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final btn = Material(
      color: c.elevated,
      shape: StadiumBorder(side: BorderSide(color: c.hairline, width: 0.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Container(
          height: SKSpacing.tapTarget,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: SKTextStyles.small.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(icon, size: 16, color: c.textPrimary),
              ],
            ],
          ),
        ),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Danger-toned button — confirm before executing at the call site.
class DestructiveButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const DestructiveButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Material(
      color: c.dangerSoft,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Container(
          height: SKSpacing.tapTarget,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: c.danger),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: SKTextStyles.small.copyWith(
                  color: c.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
