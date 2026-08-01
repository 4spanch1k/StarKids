import 'package:flutter/material.dart';

import '../../../app/config/app_environment.dart';
import '../sk_theme.dart';

String? resolveMediaImageSource(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  if (normalized.startsWith('assets/') ||
      normalized.startsWith('http://') ||
      normalized.startsWith('https://')) {
    return normalized;
  }

  if (!normalized.contains('/') && !normalized.contains('.')) {
    return 'assets/images/$normalized.jpg';
  }

  final baseUri = Uri.parse(AppEnvironment.apiBaseUrl);
  if (normalized.startsWith('/')) {
    return baseUri
        .replace(path: normalized, query: null, fragment: null)
        .toString();
  }

  return baseUri.resolve(normalized).toString();
}

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
    final resolvedSource = resolveMediaImageSource(source) ??
        resolveMediaImageSource(fallbackSource);

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
    final resolvedFallback = resolveMediaImageSource(fallbackSource);

    if (resolvedFallback == null ||
        resolvedFallback == resolveMediaImageSource(source)) {
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

  static bool _isRemote(String source) {
    return source.startsWith('http://') || source.startsWith('https://');
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.elevated),
      child: Center(
        child: Icon(Icons.image_rounded, color: c.textSecondary),
      ),
    );
  }
}
