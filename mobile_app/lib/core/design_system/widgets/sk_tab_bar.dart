import 'dart:ui';

import 'package:flutter/material.dart';

import '../foundations/sk_tokens.dart';

class SkTabItem {
  const SkTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class SkTabBar extends StatelessWidget {
  const SkTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<SkTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(SK.s4, SK.s2, SK.s4, SK.s3 + bottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SK.rPill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 66,
            padding: const EdgeInsets.all(SK.s1),
            decoration: BoxDecoration(
              color: isDark
                  ? SK.darkBgElev.withValues(alpha: 0.82)
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(SK.rPill),
              border: Border.all(color: isDark ? SK.darkLine : SK.line),
              boxShadow: isDark ? null : SK.shadowLg,
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _SkTab(
                      item: items[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkTab extends StatelessWidget {
  const _SkTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SkTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? (isDark ? SK.darkInk : SK.ink)
        : (isDark ? SK.darkInk3 : SK.ink3);

    return InkWell(
      borderRadius: BorderRadius.circular(SK.rPill),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: const Cubic(0.2, 0.8, 0.2, 1),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? SK.darkBgSoft : SK.bgSoft)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(SK.rPill),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedSlide(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              offset: selected ? const Offset(0, -0.08) : Offset.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 20, color: color),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 5,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 240),
                scale: selected ? 1 : 0,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: SK.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
