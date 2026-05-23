// GlassBottomNav — floating frosted-glass pill bottom navigation.
// iOS 26 / WhatsApp-style: ClipRRect + BackdropFilter with inner active lens.
// Use Scaffold(extendBody: true) so body content scrolls behind the pill.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../sk_color_scheme.dart';
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
    final idx = items.indexWhere((it) => it.id == value).clamp(0, items.length - 1);

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, 12 + bottomInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final navWidth = constraints.maxWidth;
          final segW = navWidth / items.length;
          final lensW = (segW * 0.88).clamp(88.0, 120.0);
          final lensX = idx * segW + (segW - lensW) / 2;

          return Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(42),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x28211E19),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Color(0x0A211E19),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(42),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c.glassTint, c.glassTint2],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Top shine line
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: Container(height: 1, color: c.glassShine),
                      ),
                      // Outer border
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(42),
                              border: Border.all(color: c.glassBorder, width: 1.0),
                            ),
                          ),
                        ),
                      ),
                      // Sliding active glass lens
                      AnimatedPositioned(
                        duration: SKMotion.base,
                        curve: SKMotion.curve,
                        left: lensX,
                        top: 10,
                        width: lensW,
                        height: 60,
                        child: _ActiveLens(colors: c),
                      ),
                      // Nav item row (above lens)
                      Positioned.fill(
                        child: Row(
                          children: items.map((it) {
                            return Expanded(
                              child: _NavBtn(
                                item: it,
                                active: it.id == value,
                                onTap: () => onChanged(it.id),
                                colors: c,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActiveLens extends StatelessWidget {
  final SKColorScheme colors;
  const _ActiveLens({required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.glassTint.withValues(alpha: 0.65),
            c.glassTint2.withValues(alpha: 0.50),
          ],
        ),
        border: Border.all(color: c.glassShine, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18211E19),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatefulWidget {
  final GlassNavItem item;
  final bool active;
  final VoidCallback onTap;
  final SKColorScheme colors;

  const _NavBtn({
    required this.item,
    required this.active,
    required this.onTap,
    required this.colors,
  });

  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: SizedBox.expand(
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
                      size: 22,
                      color: widget.active ? c.textPrimary : c.textSecondary,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.item.label,
                      style: SKTextStyles.micro.copyWith(
                        color: widget.active ? c.textPrimary : c.textSecondary,
                        fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
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
