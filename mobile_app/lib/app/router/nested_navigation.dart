import 'package:flutter/material.dart';

import 'app_routes.dart';

/// Back behavior for secondary destinations.
///
/// A nested screen normally pops from the stack. If it was launched directly
/// (deep link, restored route, notification), it falls back to Home so the
/// user can never get trapped on a dead-end screen.
void popNestedOrHome(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  navigator.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
}

class NestedBackButton extends StatelessWidget {
  const NestedBackButton({super.key, this.tooltip = 'Назад'});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      tooltip: tooltip,
      onPressed: () => popNestedOrHome(context),
    );
  }
}
