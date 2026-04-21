import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../data/api_news_repository.dart';
import '../../domain/news_item.dart';
import '../../domain/news_repository.dart';
import '../models/news_details_page_args.dart';
import '../widgets/news_image_resolver.dart';

class NewsDetailsPage extends StatefulWidget {
  const NewsDetailsPage({
    super.key,
    this.args,
  });

  final NewsDetailsPageArgs? args;

  @override
  State<NewsDetailsPage> createState() => _NewsDetailsPageState();
}

class _NewsDetailsPageState extends State<NewsDetailsPage> {
  NewsItem? _item;
  bool _isLoading = false;
  bool _isOffline = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _item = widget.args?.initialItem;
    unawaited(_loadDetails());
    unawaited(_trackView());
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;

    if (widget.args == null || widget.args!.newsId.trim().isEmpty) {
      return const _NewsDetailsStateScaffold(
        title: 'Новость не найдена',
        description: 'Не удалось открыть карточку новости.',
      );
    }

    if (_isLoading && item == null) {
      return const _NewsDetailsStateScaffold(
        title: 'Загружаем новость',
        description: 'Подтягиваем полную публикацию с сервера.',
        showProgress: true,
      );
    }

    if (item == null) {
      return _NewsDetailsStateScaffold(
        title: _isOffline ? 'Нет соединения' : 'Не удалось открыть новость',
        description:
            _errorMessage ??
            (_isOffline
                ? 'Последние данные недоступны без сети.'
                : 'Попробуйте открыть новость еще раз.'),
        actionLabel: 'Повторить',
        onPressed: _loadDetails,
      );
    }

    final imageUrl = resolveNewsImageUrl(item.imageUrl);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl.isEmpty
                  ? const _NewsDetailsImagePlaceholder()
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const _NewsDetailsImagePlaceholder(),
                      errorWidget: (_, __, ___) =>
                          const _NewsDetailsImagePlaceholder(),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                StarKidsSpacing.xl,
                StarKidsSpacing.xl,
                StarKidsSpacing.xl,
                StarKidsSpacing.x2l,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isOffline) ...[
                    const _NewsDetailsInfoBanner(
                      title: 'Нет соединения',
                      description: 'Показаны последние данные',
                    ),
                    const SizedBox(height: StarKidsSpacing.lg),
                  ],
                  Text(
                    _formatDate(item.createdAt),
                    style: textTheme.labelLarge?.copyWith(
                      color: StarKidsColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: StarKidsSpacing.md),
                  Text(
                    item.title,
                    style: textTheme.displaySmall,
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  Text(
                    (item.description ?? '').trim().isEmpty
                        ? 'Описание скоро появится.'
                        : item.description!.trim(),
                    style: textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDetails() async {
    final newsId = widget.args?.newsId.trim() ?? '';
    if (newsId.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOffline = false;
    });

    try {
      final item = await ServiceRegistry.newsRepository.getNewsDetails(newsId);
      if (!mounted) {
        return;
      }
      setState(() {
        _item = item;
        _isOffline = false;
      });
    } on NewsNetworkException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isOffline = true;
        _errorMessage = 'Показаны последние данные';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Не удалось открыть новость.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _trackView() async {
    final newsId = widget.args?.newsId.trim() ?? '';
    if (newsId.isEmpty) {
      return;
    }

    try {
      await ServiceRegistry.newsRepository.trackNewsEvent(
        newsId: newsId,
        eventType: NewsEventType.view,
      );
    } catch (_) {
      // Analytics should never block the details screen.
    }
  }

  String _formatDate(DateTime value) {
    final localDate = value.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();
    return '$day.$month.$year';
  }
}

class _NewsDetailsStateScaffold extends StatelessWidget {
  const _NewsDetailsStateScaffold({
    required this.title,
    required this.description,
    this.actionLabel,
    this.onPressed,
    this.showProgress = false,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final Future<void> Function()? onPressed;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(StarKidsSpacing.xl),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(StarKidsSpacing.xl),
            decoration: BoxDecoration(
              color: StarKidsColors.surfacePrimary,
              borderRadius: BorderRadius.circular(StarKidsRadii.xl),
              border: Border.all(color: StarKidsColors.borderDefault),
              boxShadow: StarKidsShadows.depth1,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: StarKidsSpacing.sm),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (showProgress) ...[
                  const SizedBox(height: StarKidsSpacing.xl),
                  const LinearProgressIndicator(),
                ] else if (actionLabel != null && onPressed != null) ...[
                  const SizedBox(height: StarKidsSpacing.xl),
                  FilledButton(
                    onPressed: () => onPressed!(),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsDetailsInfoBanner extends StatelessWidget {
  const _NewsDetailsInfoBanner({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(color: const Color(0xFFF2D49B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StarKidsSpacing.xs),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _NewsDetailsImagePlaceholder extends StatelessWidget {
  const _NewsDetailsImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFCE1EC),
            Color(0xFFE1EDFF),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.photo_library_rounded,
          color: StarKidsColors.textSecondary,
          size: 56,
        ),
      ),
    );
  }
}
