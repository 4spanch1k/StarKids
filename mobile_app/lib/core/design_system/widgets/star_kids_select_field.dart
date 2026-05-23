import 'package:flutter/material.dart';

import '../sk_design_tokens.dart';
import '../sk_theme.dart';

class StarKidsSelectField extends StatelessWidget {
  const StarKidsSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.leadingIcon,
    this.placeholderText = 'Выберите значение',
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final IconData? leadingIcon;
  final String placeholderText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;
    final borderColor = hasError ? c.danger : c.hairline;
    final iconColor = c.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: SKSpacing.x2,
            bottom: SKSpacing.x2,
          ),
          child: Text(label, style: textTheme.labelMedium),
        ),
        Material(
          color: c.elevated,
          borderRadius: BorderRadius.circular(SKRadius.md),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(SKRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SKSpacing.x4,
                vertical: SKSpacing.x3,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SKRadius.md),
                border: Border.all(
                  color: borderColor,
                  width: hasError ? 2 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  if (leadingIcon != null) ...[
                    Icon(
                      leadingIcon,
                      size: 20,
                      color: iconColor,
                    ),
                    const SizedBox(width: SKSpacing.x3),
                  ],
                  Expanded(
                    child: Text(
                      value ?? placeholderText,
                      style: textTheme.bodyLarge?.copyWith(
                        color: value == null ? iconColor : c.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 24,
                    color: iconColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (helperText != null || errorText != null) ...[
          const SizedBox(height: SKSpacing.x2),
          Padding(
            padding: const EdgeInsets.only(left: SKSpacing.x2),
            child: Text(
              errorText ?? helperText!,
              style: textTheme.labelMedium?.copyWith(
                color: hasError ? c.danger : iconColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
