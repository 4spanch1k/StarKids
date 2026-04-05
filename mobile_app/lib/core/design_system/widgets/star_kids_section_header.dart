import 'package:flutter/material.dart';

import '../foundations/star_kids_spacing.dart';
import 'star_kids_button.dart';

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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.headlineSmall),
              if (description != null) ...[
                const SizedBox(height: StarKidsSpacing.xs),
                Text(
                  description!,
                  style: textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onActionTap != null)
          StarKidsButton.ghost(
            label: actionLabel!,
            onPressed: onActionTap,
          ),
      ],
    );
  }
}
