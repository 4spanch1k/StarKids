import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../domain/news_item.dart';
import '../controllers/news_feed_controller.dart';
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
        NewsFeedController(repository: ServiceRegistry.newsRepository);
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
              description:
                  'Свежие анонсы и обновления из админки доступны сразу на главном экране.',
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
            else if (_controller.errorMessage != null && items.isEmpty)
              _NewsStateCard(
                title: 'Не удалось загрузить новости',
                description: _controller.errorMessage!,
                actionLabel: 'Повторить',
                onActionTap: _controller.refresh,
              )
            else if (items.isEmpty)
              const _NewsStateCard(
                title: 'Пока нет новостей',
                description: 'Новые публикации появятся здесь, как только их добавят в админке.',
              )
            else
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
                        right: index == items.length - 1 ? 0 : StarKidsSpacing.md,
                      ),
                      child: _HomeNewsCard(
                        item: item,
                        onTap: () => Navigator.of(context).pushNamed(
                          AppRoutes.notifications,
                        ),
                      ),
                    );
                  },
                ),
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
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: StarKidsShadows.cosmicCard,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
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
    return Container(
      height: 224,
      padding: const EdgeInsets.all(StarKidsSpacing.xl),
      decoration: BoxDecoration(
        color: StarKidsColors.glassSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: StarKidsColors.glassStroke),
        boxShadow: StarKidsShadows.cosmicCard,
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
            StarKidsButton.secondary(
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
          size: 40,
        ),
      ),
    );
  }
}
