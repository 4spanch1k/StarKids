import 'package:flutter/material.dart';

import '../foundations/star_kids_colors.dart';
import '../foundations/star_kids_radii.dart';
import '../foundations/star_kids_shadows.dart';
import '../foundations/star_kids_spacing.dart';

class StarKidsBottomCtaBar extends StatelessWidget {
  const StarKidsBottomCtaBar({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? StarKidsDarkColors.surfaceElevated
            : StarKidsColors.surfacePrimary,
        border: Border(
          top: BorderSide(
            color: isDark
                ? StarKidsDarkColors.borderDefault
                : StarKidsColors.borderDefault,
          ),
        ),
        boxShadow: isDark ? StarKidsShadows.depth1Dark : StarKidsShadows.depth2,
      ),
      padding: EdgeInsets.fromLTRB(
        StarKidsSpacing.xl,
        StarKidsSpacing.sm,
        StarKidsSpacing.xl,
        bottomInset + StarKidsSpacing.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        child: child,
      ),
    );
  }
}
