import 'package:flutter/material.dart';

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
        SKSpacing.x5,
        SKSpacing.x2,
        SKSpacing.x5,
        bottomInset + SKSpacing.x2,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SKRadius.xl),
        child: child,
      ),
    );
  }
}
