import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
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
            const SizedBox(height: StarKidsSpacing.lg),
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
                description:
                    'Новые публикации появятся здесь немного позже.',
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
                    const SizedBox(height: StarKidsSpacing.md),
                  ] else if (_controller.errorMessage != null) ...[
                    _NewsInlineInfoCard(
                      title: 'Не удалось обновить новости',
                      description: _controller.errorMessage!,
                    ),
                    const SizedBox(height: StarKidsSpacing.md),
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
                            right: index == items.length - 1
                                ? 0
                                : StarKidsSpacing.md,
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
          unawaited(
            precacheImage(
              CachedNetworkImageProvider(url),
              context,
            ),
          );
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
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: c.warningSoft,
        borderRadius: BorderRadius.circular(SKRadius.lg),
        border: Border.all(color: c.warning.withValues(alpha: 0.3), width: 0.5),
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
                if (imageUrl.isEmpty)
                  const _NewsImagePlaceholder()
                else
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 180),
                    placeholder: (_, __) => const _NewsImagePlaceholder(),
                    errorWidget: (_, __, ___) => const _NewsImagePlaceholder(),
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
                  left: StarKidsSpacing.lg,
                  right: StarKidsSpacing.lg,
                  bottom: StarKidsSpacing.lg,
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
  });

  final String title;
  final String description;
  final String? actionLabel;
  final Future<void> Function()? onActionTap;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Container(
      height: 224,
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.xl),
        border: Border.all(color: c.hairline, width: 0.5),
        boxShadow: SKShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
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
    );
  }
}

class _NewsImagePlaceholder extends StatelessWidget {
  const _NewsImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return DecoratedBox(
      decoration: BoxDecoration(color: c.elevated),
      child: Center(
        child: Icon(
          Icons.photo_library_rounded,
          color: c.textSecondary,
          size: 40,
        ),
      ),
    );
  }
}
