import 'package:flutter/material.dart';

import '../foundations/star_kids_spacing.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';

class StarKidsBottomCtaBar extends StatelessWidget {
  const StarKidsBottomCtaBar({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final c = SKTheme.of(context).colors;

    return Container(
      decoration: BoxDecoration(
        color: c.elevated,
        border: Border(
          top: BorderSide(color: c.hairline, width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        StarKidsSpacing.xl,
        StarKidsSpacing.sm,
        StarKidsSpacing.xl,
        bottomInset + StarKidsSpacing.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SKRadius.xl),
        child: child,
      ),
    );
  }
}
