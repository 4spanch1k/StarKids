import 'package:flutter/material.dart';

import '../foundations/star_kids_colors.dart';

class StarKidsMediaImage extends StatelessWidget {
  const StarKidsMediaImage({
    super.key,
    required this.source,
    this.fallbackSource,
    this.fit = BoxFit.cover,
  });

  final String? source;
  final String? fallbackSource;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final resolvedSource =
        _normalizeSource(source) ?? _normalizeSource(fallbackSource);

    if (resolvedSource == null) {
      return const _MediaPlaceholder();
    }

    if (_isRemote(resolvedSource)) {
      return Image.network(
        resolvedSource,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return const _MediaPlaceholder();
        },
      );
    }

    return Image.asset(
      resolvedSource,
      fit: fit,
      errorBuilder: (_, __, ___) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    final resolvedFallback = _normalizeSource(fallbackSource);

    if (resolvedFallback == null || resolvedFallback == source) {
      return const _MediaPlaceholder();
    }

    if (_isRemote(resolvedFallback)) {
      return Image.network(
        resolvedFallback,
        fit: fit,
        errorBuilder: (_, __, ___) => const _MediaPlaceholder(),
      );
    }

    return Image.asset(
      resolvedFallback,
      fit: fit,
      errorBuilder: (_, __, ___) => const _MediaPlaceholder(),
    );
  }

  static String? _normalizeSource(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static bool _isRemote(String source) {
    return source.startsWith('http://') || source.startsWith('https://');
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: StarKidsColors.surfaceSecondary,
      ),
      child: Center(
        child: Icon(
          Icons.image_rounded,
          color: StarKidsColors.textSecondary,
        ),
      ),
    );
  }
}
