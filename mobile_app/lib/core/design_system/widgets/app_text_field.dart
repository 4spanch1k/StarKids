// AppTextField — 54px tall, 16-rounded, hairline border that lifts to
// CTA-blue on focus with a 4px soft halo. Optional leading icon + suffix slot.

import 'package:flutter/material.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? leadingIcon;
  final Widget? suffix;
  final bool obscure;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final String? errorText;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.leadingIcon,
    this.suffix,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.focusNode,
    this.errorText,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focus;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: SKTextStyles.small.copyWith(
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        AnimatedContainer(
          duration: SKMotion.fast,
          curve: SKMotion.curve,
          decoration: BoxDecoration(
            color: c.elevated,
            borderRadius: BorderRadius.circular(SKRadius.md + 2),
            border: Border.all(
              color: hasError ? c.danger : (_focused ? c.cta : c.hairline),
              width: _focused || hasError ? 1.2 : 1.0,
            ),
            boxShadow: _focused && !hasError
                ? [BoxShadow(color: c.ctaSoft, blurRadius: 0, spreadRadius: 4)]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: SKSpacing.x4),
          child: Row(
            children: [
              if (widget.leadingIcon != null) ...[
                Icon(widget.leadingIcon, size: 18, color: c.textTertiary),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: widget.obscure,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  onChanged: widget.onChanged,
                  cursorColor: c.cta,
                  style: SKTextStyles.body.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: SKTextStyles.body.copyWith(
                      color: c.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.error_outline_rounded, size: 14, color: c.danger),
            const SizedBox(width: 4),
            Text(
              widget.errorText!,
              style: SKTextStyles.small.copyWith(color: c.danger),
            ),
          ]),
        ],
      ],
    );
  }
}
