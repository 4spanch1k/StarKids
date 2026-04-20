import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../news/domain/news_item.dart';
import '../../../news/presentation/controllers/news_feed_controller.dart';
import '../../../news/presentation/widgets/news_image_resolver.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    this.newsController,
  });

  final NewsFeedController? newsController;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NewsFeedController _controller;
  late final bool _ownsController;

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
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новости')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final items = _controller.items;

            if (_controller.isLoading && items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_controller.errorMessage != null && items.isEmpty) {
              return _NewsPageStateView(
                title: 'Не удалось загрузить новости',
                description: _controller.errorMessage!,
                actionLabel: 'Повторить',
                onActionTap: _controller.refresh,
              );
            }

            if (items.isEmpty) {
              return const _NewsPageStateView(
                title: 'Пока нет новостей',
                description:
                    'Когда появятся новые публикации, они сразу отобразятся в этом разделе.',
              );
            }

            return RefreshIndicator(
              onRefresh: _controller.refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(StarKidsSpacing.xl),
                itemCount: items.length + (_controller.errorMessage == null ? 0 : 1),
                separatorBuilder: (_, __) =>
                    const SizedBox(height: StarKidsSpacing.lg),
                itemBuilder: (context, index) {
                  if (_controller.errorMessage != null && index == 0) {
                    return _NewsInlineErrorCard(
                      message: _controller.errorMessage!,
                      onRetry: _controller.refresh,
                    );
                  }

                  final offset = _controller.errorMessage == null ? 0 : 1;
                  final item = items[index - offset];
                  return _NewsListCard(item: item);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NewsPageStateView extends StatelessWidget {
  const _NewsPageStateView({
    required this.title,
    required this.description,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final Future<void> Function()? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              Text(description, style: Theme.of(context).textTheme.bodyLarge),
              if (actionLabel != null && onActionTap != null) ...[
                const SizedBox(height: StarKidsSpacing.xl),
                StarKidsButton.primary(
                  label: actionLabel!,
                  onPressed: () => onActionTap!(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsInlineErrorCard extends StatelessWidget {
  const _NewsInlineErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(color: const Color(0xFFF6B9B9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Лента обновлена не полностью',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StarKidsSpacing.xs),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: StarKidsSpacing.md),
          StarKidsButton.secondary(
            label: 'Повторить',
            onPressed: () => onRetry(),
          ),
        ],
      ),
    );
  }
}

class _NewsListCard extends StatelessWidget {
  const _NewsListCard({
    required this.item,
  });

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final imageUrl = resolveNewsImageUrl(item.imageUrl);

    return Container(
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: StarKidsColors.borderDefault),
        boxShadow: StarKidsShadows.depth1,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: imageUrl.isEmpty
                  ? const _NewsImagePlaceholder()
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const _NewsImagePlaceholder(),
                      errorWidget: (_, __, ___) =>
                          const _NewsImagePlaceholder(),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(StarKidsSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(item.createdAt),
                    style: textTheme.labelMedium?.copyWith(
                      color: StarKidsColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: StarKidsSpacing.sm),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge,
                  ),
                  if ((item.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: StarKidsSpacing.sm),
                    Text(
                      item.description!.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final localDate = value.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();
    return '$day.$month.$year';
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
