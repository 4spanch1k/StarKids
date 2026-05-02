import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundations/star_kids_colors.dart';
import '../foundations/star_kids_radii.dart';
import '../foundations/star_kids_spacing.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final selectedIndex = items.indexOf(selected);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1.0 : 0.62,
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(StarKidsSpacing.xs),
        decoration: BoxDecoration(
          color: isDark
              ? StarKidsDarkColors.glassSurface
              : StarKidsColors.warmCoral,
          borderRadius: BorderRadius.circular(StarKidsRadii.full),
          border: Border.all(
            color: isDark
                ? StarKidsDarkColors.borderDefault
                : StarKidsColors.borderDefault,
          ),
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
                      color: isDark
                          ? StarKidsDarkColors.glassSurface
                          : StarKidsColors.surfacePrimary,
                      borderRadius: BorderRadius.circular(StarKidsRadii.full),
                      boxShadow: [
                        BoxShadow(
                          color: StarKidsColors.brandPrimary
                              .withValues(alpha: 0.08),
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
                              color: isSelected
                                  ? (isDark
                                      ? StarKidsDarkColors.textPrimary
                                      : StarKidsColors.textPrimary)
                                  : (isDark
                                      ? StarKidsDarkColors.textSecondary
                                      : StarKidsColors.textSecondary),
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
