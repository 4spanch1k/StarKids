import 'package:flutter/material.dart';

import '../foundations/sk_tokens.dart';

enum StarKidsButtonVariant { primary, secondary, ghost }

class StarKidsButton extends StatefulWidget {
  const StarKidsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = StarKidsButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final StarKidsButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  const StarKidsButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = StarKidsButtonVariant.primary;

  const StarKidsButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = StarKidsButtonVariant.secondary;

  const StarKidsButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  }) : variant = StarKidsButtonVariant.ghost;

  @override
  State<StarKidsButton> createState() => _StarKidsButtonState();
}

class _StarKidsButtonState extends State<StarKidsButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg, border, shadow) = switch (widget.variant) {
      StarKidsButtonVariant.primary => (
          isDark ? SK.accent : SK.accent2,
          Colors.white,
          null,
          widget.isLoading || isDisabled ? null : SK.shadowMd,
        ),
      StarKidsButtonVariant.secondary => (
          isDark ? SK.darkBgSoft : SK.bgSoft,
          isDark ? SK.darkInk : SK.ink,
          null,
          null,
        ),
      StarKidsButtonVariant.ghost => (
          Colors.transparent,
          isDark ? SK.darkInk : SK.ink,
          Border.all(color: isDark ? SK.darkLineStrong : SK.lineStrong),
          null,
        ),
    };

    final button = AnimatedScale(
      scale: _pressed ? 0.965 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.55 : 1,
        duration: const Duration(milliseconds: 160),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(SK.rPill),
          child: InkWell(
            borderRadius: BorderRadius.circular(SK.rPill),
            onTap: isDisabled ? null : widget.onPressed,
            onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            splashColor: Colors.white.withValues(alpha: 0.15),
            highlightColor: Colors.transparent,
            child: Container(
              width: widget.expand && widget.variant != StarKidsButtonVariant.ghost
                  ? double.infinity
                  : null,
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SK.rPill),
                border: border,
                boxShadow: shadow,
              ),
              child: _ButtonContent(
                label: widget.label,
                icon: widget.icon,
                isLoading: widget.isLoading,
                foregroundColor: fg,
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.expand || widget.variant == StarKidsButtonVariant.ghost) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.foregroundColor,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: foregroundColor,
        fontFamily: 'Geist',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.16,
      ),
    );

    if (isLoading) {
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: SK.s2,
        runSpacing: SK.s1,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          ),
          text,
        ],
      );
    }

    if (icon == null) {
      return text;
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: SK.s2,
      runSpacing: SK.s1,
      children: [
        Icon(icon, size: 18, color: foregroundColor),
        text,
      ],
    );
  }
}
