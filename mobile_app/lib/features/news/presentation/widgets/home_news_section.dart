import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/star_kids_media_image.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../domain/news_item.dart';
import '../controllers/news_feed_controller.dart';
import '../models/news_details_page_args.dart';
import 'news_image_resolver.dart';

class HomeNewsSection extends StatefulWidget {
  const HomeNewsSection({
    super.key,
    this.newsController,
  });

  final NewsFeedController? newsController;

  @override
  State<HomeNewsSection> createState() => _HomeNewsSectionState();
}

class _HomeNewsSectionState extends State<HomeNewsSection> {
  late final NewsFeedController _controller;
  late final bool _ownsController;
  final PageController _pageController = PageController(viewportFraction: 0.9);
  final Set<String> _preloadedUrls = <String>{};

  @override
  void initState() {
    super.initState();
    _ownsController = widget.newsController == null;
    _controller = widget.newsController ??
        NewsFeedController(
          repository: ServiceRegistry.newsRepository,
          feedKind: NewsFeedKind.promotions,
          pageSize: 6,
        );
    unawaited(_controller.bootstrap());
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final items = _controller.items;
        _schedulePrecache(items);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StarKidsSectionHeader(
              title: 'Новости',
              actionLabel: items.isEmpty ? null : 'Все новости',
              onActionTap: items.isEmpty
                  ? null
                  : () => Navigator.of(context).pushNamed(
                        AppRoutes.notifications,
                      ),
            ),
            const SizedBox(height: SKSpacing.x4),
            if (_controller.isLoading && items.isEmpty)
              const _NewsStateCard(
                title: 'Загружаем новости',
                description: 'Подтягиваем последние публикации с сервера.',
                showProgress: true,
              )
            else if (_controller.isOffline && items.isEmpty)
              _NewsStateCard(
                title: 'Нет соединения',
                description:
                    'Показаны последние данные после первой успешной загрузки.',
                actionLabel: 'Повторить',
                onActionTap: _controller.forceRefresh,
              )
            else if (_controller.errorMessage != null && items.isEmpty)
              _NewsStateCard(
                title: 'Не удалось загрузить новости',
                description: _controller.errorMessage!,
                actionLabel: 'Повторить',
                onActionTap: _controller.forceRefresh,
              )
            else if (items.isEmpty)
              const _NewsStateCard(
                title: 'Пока нет новостей',
                description: 'Новые публикации появятся здесь немного позже.',
                imageSource: 'assets/images/home_hero.jpg',
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_controller.isOffline) ...[
                    const _NewsInlineInfoCard(
                      title: 'Нет соединения',
                      description: 'Показаны последние данные',
                    ),
                    const SizedBox(height: SKSpacing.x3),
                  ] else if (_controller.errorMessage != null) ...[
                    _NewsInlineInfoCard(
                      title: 'Не удалось обновить новости',
                      description: _controller.errorMessage!,
                    ),
                    const SizedBox(height: SKSpacing.x3),
                  ],
                  SizedBox(
                    height: 224,
                    child: PageView.builder(
                      controller: _pageController,
                      allowImplicitScrolling: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index == items.length - 1 ? 0 : SKSpacing.x3,
                          ),
                          child: _HomeNewsCard(
                            item: item,
                            onTap: () {
                              unawaited(_controller.trackClick(item.id));
                              Navigator.of(context).pushNamed(
                                AppRoutes.newsDetails,
                                arguments: NewsDetailsPageArgs(
                                  newsId: item.id,
                                  initialItem: item,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  void _schedulePrecache(List<NewsItem> items) {
    if (!mounted || items.isEmpty) {
      return;
    }

    final urls = items
        .map((item) => resolveNewsImageUrl(item.imageUrl))
        .where((url) => url.isNotEmpty)
        .take(6)
        .toList(growable: false);

    if (urls.every(_preloadedUrls.contains)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      for (final url in urls) {
        if (_preloadedUrls.add(url)) {
          final provider = url.startsWith('assets/')
              ? AssetImage(url) as ImageProvider
              : CachedNetworkImageProvider(url);
          unawaited(precacheImage(provider, context));
        }
      }
    });
  }
}

class _NewsInlineInfoCard extends StatelessWidget {
  const _NewsInlineInfoCard({
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

class _HomeNewsCard extends StatelessWidget {
  const _HomeNewsCard({
    required this.item,
    required this.onTap,
  });

  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final imageUrl = resolveNewsImageUrl(item.imageUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SKRadius.xl),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SKRadius.xl),
            boxShadow: SKShadows.sm,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SKRadius.xl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                StarKidsMediaImage(
                  source: imageUrl,
                  fallbackSource: 'assets/images/home_hero.jpg',
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00110E19),
                          Color(0x22110E19),
                          Color(0xCC110E19),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: SKSpacing.x4,
                  right: SKSpacing.x4,
                  bottom: SKSpacing.x4,
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsStateCard extends StatelessWidget {
  const _NewsStateCard({
    required this.title,
    required this.description,
    this.actionLabel,
    this.onActionTap,
    this.showProgress = false,
    this.imageSource,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final Future<void> Function()? onActionTap;
  final bool showProgress;
  final String? imageSource;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Container(
      height: 224,
      padding: const EdgeInsets.all(SKSpacing.x5),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.xl),
        border: Border.all(color: c.hairline, width: 0.5),
        boxShadow: SKShadows.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageSource != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(SKRadius.lg),
              child: SizedBox(
                width: 104,
                child: StarKidsMediaImage(source: imageSource!),
              ),
            ),
            const SizedBox(width: SKSpacing.x4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: SKSpacing.x2),
                Flexible(
                  child: Text(
                    description,
                    maxLines: imageSource == null ? 4 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: imageSource == null
                        ? Theme.of(context).textTheme.bodyLarge
                        : Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (showProgress) ...[
                  const Spacer(),
                  const LinearProgressIndicator(),
                ] else if (actionLabel != null && onActionTap != null) ...[
                  const Spacer(),
                  SecondaryButton(
                    label: actionLabel!,
                    onPressed: () => onActionTap!(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
