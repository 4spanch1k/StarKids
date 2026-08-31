import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../foundations/sk_tokens.dart';
import '../sk_design_tokens.dart';
import '../sk_theme.dart';
import 'star_kids_brand_logo.dart';

/// Branded splash/loading screen.
/// Background: c.bg (existing cream token — not changed).
/// Logo: StarKidsBrandLogo at 100 px — static, no spinner.
/// Loader: lightweight glass pill with 3 pulsing dots below the subtitle.
class SkSplashView extends StatefulWidget {
  const SkSplashView({super.key});

  @override
  State<SkSplashView> createState() => _SkSplashViewState();
}

class _SkSplashViewState extends State<SkSplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotsController;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AnimatedOpacity(
              opacity: _visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 680),
              curve: Curves.easeOut,
              child: AnimatedScale(
                scale: _visible ? 1.0 : 0.94,
                duration: const Duration(milliseconds: 680),
                curve: Curves.easeOutCubic,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo + soft aura — no spinner
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  c.accent.withValues(alpha: 0.13),
                                  SK.sun.withValues(alpha: 0.05),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: c.accent.withValues(alpha: 0.08),
                                blurRadius: 28,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: const StarKidsBrandLogo(
                            logoSize: 100,
                            maxRelativeSize: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Boom Bala',
                      style: SKTextStyles.d2.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Семейный отдых и яркие дни рождения',
                      textAlign: TextAlign.center,
                      style: SKTextStyles.body.copyWith(
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _GlassLoadingPill(controller: _dotsController),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 84×36 pill loader — warm white tint, thin border, soft shadow, 3 coral dots.
/// No BackdropFilter: cream bg is solid, blur adds nothing.
class _GlassLoadingPill extends StatelessWidget {
  const _GlassLoadingPill({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Container(
      width: 84,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SK.rPill),
        color: Colors.white.withValues(alpha: 0.74),
        border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (controller.value - i * 0.22).clamp(0.0, 1.0);
            final pulse = math.sin(phase * math.pi).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: 0.3 + pulse * 0.7,
                child: Transform.scale(
                  scale: 0.85 + pulse * 0.15,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accent.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
