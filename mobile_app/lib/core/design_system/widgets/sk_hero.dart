import 'package:flutter/material.dart';

import '../foundations/sk_tokens.dart';
import 'star_kids_media_image.dart';

class SkHero extends StatelessWidget {
  const SkHero({
    super.key,
    required this.imageUrl,
    this.fallbackImagePath,
    required this.title,
    this.italicText,
    this.chip,
    this.meta,
    this.action,
    this.aspectRatio = 4 / 5,
  });

  final String imageUrl;
  final String? fallbackImagePath;
  final String title;
  final String? italicText;
  final String? chip;
  final String? meta;
  final Widget? action;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final resolvedAspectRatio =
            compact && aspectRatio == 4 / 5 ? 0.92 : aspectRatio;
        final edge = compact ? SK.s4 : SK.s6;

        return ClipRRect(
          borderRadius: BorderRadius.circular(compact ? SK.rLg : SK.rXl),
          child: AspectRatio(
            aspectRatio: resolvedAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                StarKidsMediaImage(
                  source: imageUrl,
                  fallbackSource: fallbackImagePath,
                  fit: BoxFit.cover,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xA6000000),
                        Color(0x33000000),
                        Colors.transparent,
                      ],
                      stops: [0, 0.54, 0.82],
                    ),
                  ),
                ),
                Positioned(
                  left: edge,
                  right: edge,
                  bottom: edge,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chip != null) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? SK.s2 : SK.s3,
                            vertical: compact ? SK.s1 : SK.s2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x990F172A),
                            borderRadius: BorderRadius.circular(SK.rPill),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            chip!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Geist',
                              color: Colors.white,
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? SK.s2 : SK.s3),
                      ],
                      _HeroTitle(
                        title: title,
                        italicText: italicText,
                        compact: compact,
                      ),
                      if (meta != null) ...[
                        SizedBox(height: compact ? SK.s2 : SK.s3),
                        Text(
                          meta!,
                          style: TextStyle(
                            fontFamily: 'Geist',
                            color: const Color(0xD9FFFFFF),
                            fontSize: compact ? 12 : 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (action != null) ...[
                        SizedBox(height: compact ? SK.s3 : SK.s5),
                        action!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({
    required this.title,
    required this.compact,
    this.italicText,
  });

  final String title;
  final String? italicText;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final italic = italicText;
    if (italic == null || !title.contains(italic)) {
      return Text(
        title,
        style: TextStyle(
          fontFamily: 'Fraunces',
          color: Colors.white,
          fontSize: compact ? 28 : 34,
          height: 1.02,
          letterSpacing: -0.85,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    final parts = title.split(italic);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: parts.first),
          TextSpan(
            text: italic,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
          TextSpan(text: parts.skip(1).join(italic)),
        ],
      ),
      style: TextStyle(
        fontFamily: 'Fraunces',
        color: Colors.white,
        fontSize: compact ? 28 : 34,
        height: 1.02,
        letterSpacing: -0.85,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
