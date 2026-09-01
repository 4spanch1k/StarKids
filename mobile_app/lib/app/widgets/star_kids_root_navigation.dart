import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design_system/widgets/glass_bottom_nav.dart';
import '../router/app_routes.dart';

/// Persistent navigation shared by the five authenticated root destinations.
class StarKidsRootNavigation extends StatefulWidget {
  const StarKidsRootNavigation({super.key, required this.current});

  final String current;

  @override
  State<StarKidsRootNavigation> createState() => _StarKidsRootNavigationState();
}

class _StarKidsRootNavigationState extends State<StarKidsRootNavigation> {
  static const items = <GlassNavItem>[
    GlassNavItem(id: 'home', icon: Icons.home_rounded, label: 'Главная'),
    GlassNavItem(
      id: 'tickets',
      icon: Icons.confirmation_num_rounded,
      label: 'Билеты',
    ),
    GlassNavItem(id: 'afisha', icon: Icons.event_rounded, label: 'Афиша'),
    GlassNavItem(id: 'birthdays', icon: Icons.cake_rounded, label: 'Праздники'),
    GlassNavItem(id: 'profile', icon: Icons.person_rounded, label: 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassBottomNav(
      items: items,
      value: widget.current,
      onChanged: _isNavigating ? (_) {} : (id) => unawaited(_open(context, id)),
    );
  }

  bool _isNavigating = false;

  Future<void> _open(BuildContext context, String id) async {
    if (id == widget.current || _isNavigating) return;
    setState(() => _isNavigating = true);
    try {
      if (id == 'tickets') {
        await Navigator.of(
          this.context,
        ).pushReplacementNamed(AppRoutes.tickets);
        return;
      }

      final route = switch (id) {
        'home' => AppRoutes.home,
        'afisha' => AppRoutes.afisha,
        'birthdays' => AppRoutes.birthdays,
        'profile' => AppRoutes.profile,
        _ => null,
      };
      if (route != null && mounted) {
        await Navigator.of(this.context).pushReplacementNamed(route);
      }
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }
}
