import 'dart:ui';

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(SK.rXl),
      child: AspectRatio(
        aspectRatio: aspectRatio,
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
              left: SK.s6,
              right: SK.s6,
              bottom: SK.s6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (chip != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(SK.rPill),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SK.s3,
                            vertical: SK.s2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(SK.rPill),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            chip!,
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: SK.s3),
                  ],
                  _HeroTitle(title: title, italicText: italicText),
                  if (meta != null) ...[
                    const SizedBox(height: SK.s3),
                    Text(
                      meta!,
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        color: Color(0xD9FFFFFF),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: SK.s5),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({required this.title, this.italicText});

  final String title;
  final String? italicText;

  @override
  Widget build(BuildContext context) {
    final italic = italicText;
    if (italic == null || !title.contains(italic)) {
      return Text(
        title,
        style: const TextStyle(
          fontFamily: 'Fraunces',
          color: Colors.white,
          fontSize: 34,
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
      style: const TextStyle(
        fontFamily: 'Fraunces',
        color: Colors.white,
        fontSize: 34,
        height: 1.02,
        letterSpacing: -0.85,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
