// GlassDrawer — 84%-width side drawer for secondary navigation.
// Heavy blur + high opacity so content behind stays partially visible.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';

class GlassDrawer extends StatelessWidget {
  final Widget child;
  const GlassDrawer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final w = MediaQuery.of(context).size.width * 0.84;
    return SizedBox(
      width: w,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(SKRadius.xl),
          bottomRight: Radius.circular(SKRadius.xl),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: SKBlur.heavy, sigmaY: SKBlur.heavy),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.bg.withValues(alpha: 0.80),
                  c.bg.withValues(alpha: 0.76),
                ],
              ),
              border: Border(
                right: BorderSide(color: c.glassBorder, width: 1.0),
              ),
            ),
            child: SafeArea(child: child),
          ),
        ),
      ),
    );
  }
}

/// Tappable row inside GlassDrawer.
class GlassDrawerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String? badge;
  final VoidCallback? onTap;

  const GlassDrawerRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SKRadius.md),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(SKRadius.md),
                    ),
                    child: Icon(icon, size: 17, color: c.textPrimary),
                  ),
                  const SizedBox(width: SKSpacing.x3),
                  Expanded(
                    child: Text(
                      label,
                      style: SKTextStyles.body.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  if (value != null)
                    Text(
                      value!,
                      style: SKTextStyles.small.copyWith(color: c.textTertiary),
                    ),
                  if (badge != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        borderRadius: BorderRadius.circular(SKRadius.pill),
                      ),
                      child: Text(
                        badge!,
                        style: SKTextStyles.micro.copyWith(color: c.accent),
                      ),
                    ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: c.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
