import 'dart:async';

import 'package:flutter/material.dart';

const starKidsPageTransitionDuration = Duration(milliseconds: 300);
const starKidsMotionDuration = Duration(milliseconds: 220);
const starKidsPressMotionDuration = Duration(milliseconds: 110);
const starKidsMotionOffset = Offset(0, 0.04);

Duration starKidsStaggerDelay(int index, {int initialMs = 0, int stepMs = 40}) {
  return Duration(milliseconds: initialMs + (index * stepMs));
}

Route<T> buildStarKidsPageRoute<T>({
  required Widget page,
  required RouteSettings settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: starKidsPageTransitionDuration,
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeInOut,
      );

      return FadeTransition(opacity: fadeAnimation, child: child);
    },
  );
}

Future<T?> showStarKidsModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  Clip? clipBehavior,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    shape: shape,
    clipBehavior: clipBehavior,
    builder: (context) => StarKidsReveal(
      duration: starKidsMotionDuration,
      beginOffset: const Offset(0, 0.06),
      curve: Curves.easeOutCubic,
      child: builder(context),
    ),
  );
}

class StarKidsReveal extends StatefulWidget {
  const StarKidsReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = starKidsMotionDuration,
    this.curve = Curves.easeOutCubic,
    this.beginOffset = starKidsMotionOffset,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Offset beginOffset;

  @override
  State<StarKidsReveal> createState() => _StarKidsRevealState();
}

class _StarKidsRevealState extends State<StarKidsReveal> {
  Timer? _timer;
  var _isVisible = false;

  @override
  void initState() {
    super.initState();
    _scheduleReveal();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleReveal() {
    if (widget.delay == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isVisible = true;
        });
      });
      return;
    }

    _timer = Timer(widget.delay, () {
      if (!mounted) {
        return;
      }

      setState(() {
        _isVisible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: widget.duration,
      curve: widget.curve,
      opacity: _isVisible ? 1 : 0,
      child: AnimatedSlide(
        duration: widget.duration,
        curve: widget.curve,
        offset: _isVisible ? Offset.zero : widget.beginOffset,
        child: widget.child,
      ),
    );
  }
}

class StarKidsContentSwitcher extends StatelessWidget {
  const StarKidsContentSwitcher({
    super.key,
    required this.child,
    this.duration = starKidsMotionDuration,
    this.beginOffset = starKidsMotionOffset,
  });

  final Widget child;
  final Duration duration;
  final Offset beginOffset;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        final transition = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
          reverseCurve: Curves.easeInOut,
        );

        return FadeTransition(
          opacity: transition,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(transition),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Elastic liquid press effect: presses down quickly and bounces back
/// with a springy elastic out curve for a satisfying "liquid" feel.
class StarKidsPressEffect extends StatefulWidget {
  const StarKidsPressEffect({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<StarKidsPressEffect> createState() => _StarKidsPressEffectState();
}

class _StarKidsPressEffectState extends State<StarKidsPressEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      reverseDuration: const Duration(milliseconds: 380),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.968).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInCubic,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (!widget.enabled) return;
    if (pressed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
