import 'package:flutter/material.dart';

import '../sk_design_tokens.dart';
import '../sk_theme.dart';

class StarKidsSectionHeader extends StatelessWidget {
  const StarKidsSectionHeader({
    super.key,
    required this.title,
    this.description,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.headlineSmall),
              if (description != null) ...[
                const SizedBox(height: SKSpacing.x1),
                Text(description!, style: textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onActionTap != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(foregroundColor: c.cta),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
