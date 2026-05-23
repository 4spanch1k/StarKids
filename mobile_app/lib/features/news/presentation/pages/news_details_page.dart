import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
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
    final c = SKTheme.of(context).colors;

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
                SKSpacing.x5,
                SKSpacing.x5,
                SKSpacing.x5,
                SKSpacing.x6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isOffline) ...[
                    const _NewsDetailsInfoBanner(
                      title: 'Нет соединения',
                      description: 'Показаны последние данные',
                    ),
                    const SizedBox(height: SKSpacing.x4),
                  ],
                  Text(
                    _formatDate(item.createdAt),
                    style: textTheme.labelLarge?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: SKSpacing.x3),
                  Text(
                    item.title,
                    style: textTheme.displaySmall,
                  ),
                  const SizedBox(height: SKSpacing.x4),
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
    final c = SKTheme.of(context).colors;

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(SKSpacing.x5),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SKSpacing.x5),
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(SKRadius.xl),
              border: Border.all(color: c.hairline, width: 0.5),
              boxShadow: SKShadows.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: SKSpacing.x2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (showProgress) ...[
                  const SizedBox(height: SKSpacing.x5),
                  const LinearProgressIndicator(),
                ] else if (actionLabel != null && onPressed != null) ...[
                  const SizedBox(height: SKSpacing.x5),
                  PrimaryButton(
                    onPressed: () => onPressed!(),
                    label: actionLabel!,
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
    final c = SKTheme.of(context).colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SKSpacing.x4),
      decoration: BoxDecoration(
        color: c.warningSoft,
        borderRadius: BorderRadius.circular(SKRadius.lg),
        border: Border.all(color: c.warning.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SKSpacing.x1),
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
    final c = SKTheme.of(context).colors;

    return DecoratedBox(
      decoration: BoxDecoration(color: c.elevated),
      child: Center(
        child: Icon(
          Icons.photo_library_rounded,
          color: c.textSecondary,
          size: 56,
        ),
      ),
    );
  }
}
