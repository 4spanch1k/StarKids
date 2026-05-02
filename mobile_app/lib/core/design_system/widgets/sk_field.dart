import 'package:flutter/material.dart';

import '../foundations/sk_tokens.dart';

class SkField extends StatefulWidget {
  const SkField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.icon,
    this.trailing,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? icon;
  final Widget? trailing;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;

  @override
  State<SkField> createState() => _SkFieldState();
}

class _SkFieldState extends State<SkField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SK.darkBgElev : SK.bgElev;
    final ink = isDark ? SK.darkInk : SK.ink;
    final meta = isDark ? SK.darkInk3 : SK.ink3;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SK.rLg),
        border: Border.all(
          color: focused
              ? (isDark ? SK.darkInk2 : SK.ink2)
              : (isDark ? SK.darkLine : SK.line),
        ),
        boxShadow: focused
            ? const [
                BoxShadow(
                  color: SK.accentSoft,
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: SK.s4, vertical: SK.s2),
      child: Row(
        crossAxisAlignment: widget.maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Padding(
              padding: EdgeInsets.only(top: widget.maxLines > 1 ? SK.s3 : 0),
              child: Icon(widget.icon, size: 20, color: meta),
            ),
            const SizedBox(width: SK.s3),
          ],
          Expanded(
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              validator: widget.validator,
              onChanged: widget.onChanged,
              maxLines: widget.obscureText ? 1 : widget.maxLines,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 15,
                height: 1.35,
                color: ink,
              ),
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hintText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                labelStyle: TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: 11,
                  letterSpacing: 1.32,
                  color: meta,
                ),
                hintStyle: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 15,
                  color: isDark ? SK.darkInk3 : SK.ink4,
                ),
              ),
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: SK.s2),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}
