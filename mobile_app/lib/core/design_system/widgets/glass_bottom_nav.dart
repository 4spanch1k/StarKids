// GlassBottomNav — floating glass-pill bottom navigation.
// Active item gets a sliding coral-accent capsule indicator.
// Sits inside the Scaffold body via a Stack; use Scaffold.extendBody: true.

import 'package:flutter/material.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';
import 'glass_container.dart';

class GlassNavItem {
  final String id;
  final IconData icon;
  final String label;
  const GlassNavItem({
    required this.id,
    required this.icon,
    required this.label,
  });
}

class GlassBottomNav extends StatelessWidget {
  final List<GlassNavItem> items;
  final String value;
  final ValueChanged<String> onChanged;

  const GlassBottomNav({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final idx = items
        .indexWhere((it) => it.id == value)
        .clamp(0, items.length - 1);

    return Padding(
      padding: EdgeInsets.only(
        left: SKSpacing.gutter,
        right: SKSpacing.gutter,
        bottom: 14 + MediaQuery.of(context).padding.bottom * 0.4,
      ),
      child: GlassContainer(
        radius: SKRadius.pill,
        blur: SKBlur.base,
        shadow: SKShadows.lg,
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: 56,
          child: LayoutBuilder(
            builder: (context, cons) {
              final segW = cons.maxWidth / items.length;
              return Stack(
                children: [
                  // sliding active indicator
                  AnimatedPositioned(
                    duration: SKMotion.base,
                    curve: SKMotion.curve,
                    left: idx * segW,
                    top: 0,
                    bottom: 0,
                    width: segW,
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(SKRadius.pill),
                        boxShadow: SKShadows.sm,
                      ),
                    ),
                  ),
                  Row(
                    children: items.map((it) {
                      return Expanded(
                        child: _NavBtn(
                          item: it,
                          active: it.id == value,
                          onTap: () => onChanged(it.id),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final GlassNavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavBtn({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SKRadius.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: active ? Colors.white : c.textSecondary,
                ),
                if (active) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      item.label,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: SKTextStyles.small.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
