import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';

class ProfileShimmerBlock extends StatefulWidget {
  const ProfileShimmerBlock({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
  });

  final double height;
  final double? width;
  final double? borderRadius;

  @override
  State<ProfileShimmerBlock> createState() => _ProfileShimmerBlockState();
}

class _ProfileShimmerBlockState extends State<ProfileShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              widget.borderRadius ?? StarKidsRadii.sm,
            ),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFEDE0E8),
                Color(0xFFF8F0F5),
                Color(0xFFEDE0E8),
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProfileLoadingSkeleton extends StatelessWidget {
  const ProfileLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderSkeleton(),
          const SizedBox(height: StarKidsSpacing.xl),
          const _CardSkeleton(lineCount: 4),
          const SizedBox(height: StarKidsSpacing.xl),
          const _CardSkeleton(lineCount: 3),
          const SizedBox(height: StarKidsSpacing.xl),
          const _CardSkeleton(lineCount: 3),
          const SizedBox(height: StarKidsSpacing.xl),
          const _CardSkeleton(lineCount: 2),
        ],
      ),
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(color: StarKidsColors.borderDefault),
      ),
      child: const Row(
        children: [
          ProfileShimmerBlock(
            height: 80,
            width: 80,
            borderRadius: 40,
          ),
          SizedBox(width: StarKidsSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileShimmerBlock(height: 20, width: 160),
                SizedBox(height: StarKidsSpacing.sm),
                ProfileShimmerBlock(height: 16, width: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({required this.lineCount});

  final int lineCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(color: StarKidsColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileShimmerBlock(height: 20, width: 140),
          const SizedBox(height: StarKidsSpacing.lg),
          for (var i = 0; i < lineCount; i++) ...[
            if (i > 0) const SizedBox(height: StarKidsSpacing.md),
            const ProfileShimmerBlock(height: 16),
          ],
        ],
      ),
    );
  }
}
