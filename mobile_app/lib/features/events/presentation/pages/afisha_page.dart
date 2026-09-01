import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/widgets/star_kids_root_navigation.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/star_kids_media_image.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../features/news/domain/news_item.dart';
import '../../../../features/news/presentation/controllers/news_feed_controller.dart';
import '../../../../features/news/presentation/models/news_details_page_args.dart';
import '../../../../features/news/presentation/widgets/news_image_resolver.dart';

/// Retention-led event feed. It consumes the existing public news contract;
/// event-specific metadata can be added to NewsItem later without changing
/// this navigation surface.
class AfishaPage extends StatefulWidget {
  const AfishaPage({super.key, this.controller});

  final NewsFeedController? controller;

  @override
  State<AfishaPage> createState() => _AfishaPageState();
}

class _AfishaPageState extends State<AfishaPage> {
  late final NewsFeedController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        NewsFeedController(
          repository: ServiceRegistry.newsRepository,
          feedKind: NewsFeedKind.promotions,
          pageSize: 12,
        );
    unawaited(_controller.bootstrap());
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: GlassAppBar(
        leading: const SizedBox(width: 44),
        title: Text('Афиша', style: Theme.of(context).textTheme.titleLarge),
        trailing: GlassIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Уведомления',
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.notifications),
        ),
      ),
      bottomNavigationBar: const StarKidsRootNavigation(current: 'afisha'),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _controller.forceRefresh,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final items = _controller.items;
    if (_controller.isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.errorMessage != null && items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SKSpacing.x6),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.cloud_off_rounded,
              size: 48, color: SKTheme.of(context).colors.textTertiary),
          const SizedBox(height: SKSpacing.x3),
          Text('Афиша временно недоступна',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SKSpacing.x2),
          Text(_controller.errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: SKSpacing.x4),
          Center(
            child: TextButton(
              onPressed: _controller.forceRefresh,
              child: const Text('Повторить'),
            ),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          SKSpacing.x5,
          SKSpacing.x5,
          SKSpacing.x5,
          MediaQuery.viewPaddingOf(context).bottom + 96,
        ),
        children: const [
          SizedBox(height: 96),
          _AfishaEmptyState(),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        SKSpacing.x5,
        SKSpacing.x4,
        SKSpacing.x5,
        MediaQuery.viewPaddingOf(context).bottom + 96,
      ),
      children: [
        Text('Ближайшие события',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: SKSpacing.x1),
        Text(
          'Выбирайте повод для следующего семейного дня.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: SKTheme.of(context).colors.textSecondary,
              ),
        ),
        const SizedBox(height: SKSpacing.x4),
        ...items.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: SKSpacing.x4),
                child: _EventCard(
                  item: entry.value,
                  revealDelay: starKidsStaggerDelay(entry.key),
                  onTap: () {
                    unawaited(_controller.trackClick(entry.value.id));
                    Navigator.of(context).pushNamed(
                      AppRoutes.newsDetails,
                      arguments: NewsDetailsPageArgs(
                        newsId: entry.value.id,
                        initialItem: entry.value,
                      ),
                    );
                  },
                ),
              ),
            ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.item,
    required this.revealDelay,
    required this.onTap,
  });

  final NewsItem item;
  final Duration revealDelay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final image = resolveNewsImageUrl(item.imageUrl);
    return StarKidsReveal(
      delay: revealDelay,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SKRadius.xl),
          child: Ink(
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(SKRadius.xl),
              border: Border.all(color: c.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(SKRadius.xl),
                  ),
                  child: SizedBox(
                    height: 168,
                    width: double.infinity,
                    child: StarKidsMediaImage(
                      source: image,
                      fallbackSource: 'assets/images/home_hero.jpg',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(SKSpacing.x4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                style: Theme.of(context).textTheme.titleLarge),
                            if (item.description?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: SKSpacing.x1),
                              Text(
                                item.description!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: SKSpacing.x2),
                            Text(
                              _formatDate(item.createdAt),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: SKSpacing.x2),
                      Icon(Icons.arrow_forward_rounded, color: c.cta),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
}

class _AfishaEmptyState extends StatelessWidget {
  const _AfishaEmptyState();

  @override
  Widget build(BuildContext context) {
    return SolidCard(
      padding: const EdgeInsets.all(SKSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_available_rounded,
              size: 32, color: SKTheme.of(context).colors.accent),
          const SizedBox(height: SKSpacing.x3),
          Text('На ближайшие дни событий пока нет',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SKSpacing.x2),
          Text(
              'Загляните позже или выберите обычный билет для следующего визита.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: SKSpacing.x3),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.tickets),
            child: const Text('Купить билет'),
          ),
        ],
      ),
    );
  }
}
