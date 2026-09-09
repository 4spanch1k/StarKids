import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sk_design_tokens.dart';
import '../sk_theme.dart';

class SkSegment<T> extends StatelessWidget {
  const SkSegment({
    super.key,
    required this.items,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    this.enabled = true,
  });

  final List<T> items;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final textTheme = Theme.of(context).textTheme;
    final selectedIndex = items.indexOf(selected);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1.0 : 0.62,
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(SKSpacing.x1),
        decoration: BoxDecoration(
          color: c.glassTint,
          borderRadius: BorderRadius.circular(SKRadius.pill),
          border: Border.all(color: c.glassBorder, width: 1.0),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pillWidth = constraints.maxWidth / items.length;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: const Cubic(0.05, 0.7, 0.1, 1.0),
                  left: selectedIndex * pillWidth,
                  top: 0,
                  bottom: 0,
                  width: pillWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(SKRadius.pill),
                      boxShadow: [
                        BoxShadow(
                          color: c.cta.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: items.map((item) {
                    final isSelected = item == selected;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: enabled
                            ? () {
                                HapticFeedback.selectionClick();
                                onSelected(item);
                              }
                            : null,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: (textTheme.labelLarge ?? const TextStyle())
                                .copyWith(
                              color:
                                  isSelected ? c.textPrimary : c.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                            child: Text(labelBuilder(item)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
