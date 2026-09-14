import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundations/sk_tokens.dart';
import 'sk_pressable.dart';

class SkStepper extends StatelessWidget {
  const SkStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.keyPrefix,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SK.darkBgSoft : SK.bgSoft;
    final border = isDark ? SK.darkLine : SK.line;
    final ink = isDark ? SK.darkInk : SK.ink;

    return Container(
      padding: const EdgeInsets.all(SK.s1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SK.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundStepButton(
            key: keyPrefix == null
                ? null
                : ValueKey('ticket-decrease-$keyPrefix'),
            icon: Icons.remove,
            enabled: value > min,
            border: border,
            ink: ink,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(value - 1);
            },
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              key: keyPrefix == null
                  ? null
                  : ValueKey('ticket-count-$keyPrefix'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          _RoundStepButton(
            key: keyPrefix == null
                ? null
                : ValueKey('ticket-increase-$keyPrefix'),
            icon: Icons.add,
            enabled: value < max,
            border: border,
            ink: ink,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(value + 1);
            },
          ),
        ],
      ),
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.border,
    required this.ink,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final Color border;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: SkPressable(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(SK.rPill),
        scale: 0.92,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? SK.darkBgElev : SK.bgElev,
            borderRadius: BorderRadius.circular(SK.rPill),
            border: Border.all(color: border),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            splashRadius: 18,
            onPressed: enabled ? onTap : null,
            icon: Icon(icon, size: 18, color: ink),
          ),
        ),
      ),
    );
  }
}
