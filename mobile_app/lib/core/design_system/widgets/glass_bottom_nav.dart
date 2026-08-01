// Kept under the existing name to avoid breaking callers. The navigation is a
// solid, cross-platform surface rather than a blurred iOS-style glass panel.

import 'package:flutter/material.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';

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
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 8 + bottomInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final navWidth = constraints.maxWidth;
          final compact = navWidth < 380;

          return Container(
            height: 68,
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(SKRadius.lg),
              border: Border.all(color: c.hairline),
              boxShadow: SKShadows.md,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SKRadius.lg),
              child: Row(
                children: items.map((it) {
                  return Expanded(
                    child: _NavBtn(
                      item: it,
                      active: it.id == value,
                      onTap: () => onChanged(it.id),
                      compact: compact,
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavBtn extends StatefulWidget {
  final GlassNavItem item;
  final bool active;
  final VoidCallback onTap;
  final bool compact;

  const _NavBtn({
    required this.item,
    required this.active,
    required this.onTap,
    required this.compact,
  });

  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SKRadius.md),
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: SKMotion.fast,
            curve: SKMotion.curve,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: widget.active ? c.ctaSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(SKRadius.md),
            ),
            child: Center(
              child: AnimatedScale(
                scale: _pressed ? 0.86 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.item.icon,
                      size: widget.compact ? 20 : 22,
                      color: widget.active ? c.cta : c.textSecondary,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: SKTextStyles.micro.copyWith(
                        color: widget.active ? c.textPrimary : c.textSecondary,
                        fontWeight:
                            widget.active ? FontWeight.w700 : FontWeight.w500,
                        fontSize: widget.compact ? 9.5 : null,
                        letterSpacing: widget.compact ? 0 : null,
                        height: 1.05,
                      ),
                    ),
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
