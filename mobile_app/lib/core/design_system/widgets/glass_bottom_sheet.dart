// showGlassBottomSheet — modal with solid body (readability) and glass chrome.
// Driven by DraggableScrollableSheet for drag + scroll.

import 'package:flutter/material.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';

Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext, ScrollController) builder,
  String? title,
  String? step,
  Widget? action,          // sticky bottom CTA bar
  double initialSize = 0.7,
  double minSize = 0.4,
  double maxSize = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x6B14110D),
    useSafeArea: false,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: initialSize,
        minChildSize: minSize,
        maxChildSize: maxSize,
        expand: false,
        builder: (ctx, scroll) => _SheetShell(
          title: title,
          step: step,
          action: action,
          scrollController: scroll,
          child: builder(ctx, scroll),
        ),
      );
    },
  );
}

class _SheetShell extends StatelessWidget {
  final Widget child;
  final ScrollController scrollController;
  final String? title;
  final String? step;
  final Widget? action;

  const _SheetShell({
    required this.child,
    required this.scrollController,
    this.title,
    this.step,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: Container(
        color: c.elevated,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: c.textTertiary,
                  borderRadius: BorderRadius.circular(SKRadius.pill),
                ),
              ),
            ),
            if (title != null) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(
                  SKSpacing.x5, SKSpacing.x2, SKSpacing.x5, SKSpacing.x4,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: c.hairline, width: 0.5),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(children: [
                      Text(
                        title!,
                        style: SKTextStyles.h2.copyWith(
                          color: c.textPrimary,
                          fontFamily: SKTypography.display,
                        ),
                      ),
                      if (step != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            step!,
                            style: SKTextStyles.small.copyWith(
                              color: c.textTertiary,
                            ),
                          ),
                        ),
                    ]),
                    Positioned(right: 0, child: _CloseBtn()),
                  ],
                ),
              ),
            ],
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: child,
              ),
            ),
            if (action != null)
              Container(
                decoration: BoxDecoration(
                  color: c.elevated,
                  border: Border(
                    top: BorderSide(color: c.hairline, width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  SKSpacing.x4, SKSpacing.x3, SKSpacing.x4, SKSpacing.x4,
                ),
                child: SafeArea(top: false, child: action!),
              ),
          ],
        ),
      ),
    );
  }
}

class _CloseBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Semantics(
      button: true,
      label: 'Закрыть',
      child: Material(
        color: c.bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).maybePop(),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
