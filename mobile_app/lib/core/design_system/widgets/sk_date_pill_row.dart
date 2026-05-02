import 'package:flutter/material.dart';

import '../foundations/star_kids_colors.dart';
import '../foundations/star_kids_radii.dart';
import '../foundations/star_kids_spacing.dart';

class SkDatePillRow extends StatelessWidget {
  const SkDatePillRow({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.daysAhead = 30,
  });

  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final int daysAhead;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dates = List.generate(
      daysAhead,
      (i) => DateTime(today.year, today.month, today.day + i + 1),
    );

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: StarKidsSpacing.sm),
        itemBuilder: (context, i) {
          final date = dates[i];
          final isSelected = selectedDate != null &&
              date.year == selectedDate!.year &&
              date.month == selectedDate!.month &&
              date.day == selectedDate!.day;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? StarKidsColors.brandPrimary
                    : (isDark
                        ? StarKidsDarkColors.surfaceElevated
                        : StarKidsColors.surfacePrimary),
                borderRadius: BorderRadius.circular(StarKidsRadii.md),
                border: Border.all(
                  color: isSelected
                      ? StarKidsColors.brandPrimary
                      : (isDark
                          ? StarKidsDarkColors.borderDefault
                          : StarKidsColors.borderDefault),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayRu(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? StarKidsDarkColors.textSecondary
                              : StarKidsColors.textSecondary),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? StarKidsDarkColors.textPrimary
                              : StarKidsColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

String _weekdayRu(DateTime date) {
  const days = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
  return days[date.weekday - 1];
}
