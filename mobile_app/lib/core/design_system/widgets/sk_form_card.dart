import 'package:flutter/material.dart';

import '../foundations/sk_tokens.dart';

class SkFormCard extends StatelessWidget {
  const SkFormCard({
    super.key,
    required this.children,
    this.padding =
        const EdgeInsets.symmetric(horizontal: SK.s5, vertical: SK.s2),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final line = isDark ? SK.darkLine : SK.line;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? SK.darkBgElev : SK.bgElev,
        borderRadius: BorderRadius.circular(SK.rLg),
        border: Border.all(color: line),
        boxShadow: isDark ? null : SK.shadowSm,
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Padding(padding: padding, child: children[i]),
            if (i != children.length - 1)
              Divider(height: 1, thickness: 1, color: line),
          ],
        ],
      ),
    );
  }
}

class SkFormRow extends StatelessWidget {
  const SkFormRow({
    super.key,
    required this.label,
    required this.child,
    this.icon,
    this.onTap,
  });

  final String label;
  final Widget child;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = isDark ? SK.darkInk3 : SK.ink3;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: meta),
          const SizedBox(width: SK.s3),
        ],
        SizedBox(
          width: 86,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 11,
              height: 1.2,
              letterSpacing: 1.32,
              color: meta,
            ),
          ),
        ),
        const SizedBox(width: SK.s3),
        Expanded(child: child),
      ],
    );

    if (onTap == null) {
      return row;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(SK.rMd),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SK.s3),
        child: row,
      ),
    );
  }
}
