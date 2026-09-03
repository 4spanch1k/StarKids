import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sk_design_tokens.dart';
import '../sk_theme.dart';

class SkGuestStepper extends StatelessWidget {
  const SkGuestStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 30,
    this.label = 'Количество гостей',
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SKSpacing.x4,
        vertical: SKSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.lg),
        border: Border.all(color: c.hairline, width: 0.5),
        boxShadow: SKShadows.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.labelMedium),
                const SizedBox(height: 2),
                Text('$value гостей', style: textTheme.titleMedium),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: value > min,
            onTap: () {
              if (value > min) {
                HapticFeedback.selectionClick();
                onChanged(value - 1);
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SKSpacing.x3),
            child: Text(
              value.toString(),
              style: textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: value < max,
            onTap: () {
              if (value < max) {
                HapticFeedback.selectionClick();
                onChanged(value + 1);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatefulWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(SKRadius.pill),
              border: Border.all(color: c.hairline),
            ),
            child: Icon(widget.icon, size: 18, color: c.textPrimary),
          ),
        ),
      ),
    );
  }
}
