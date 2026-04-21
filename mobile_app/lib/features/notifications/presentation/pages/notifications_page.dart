import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../news/domain/news_item.dart';
import '../../../news/domain/news_repository.dart';
import '../../../news/presentation/models/news_details_page_args.dart';
import '../../../news/presentation/widgets/news_image_resolver.dart';
import '../../domain/app_notification.dart';
import '../controllers/notification_history_controller.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    this.controller,
  });

  final NotificationHistoryController? controller;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationHistoryController _controller;
  late final bool _ownsController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        NotificationHistoryController(
          repository: ServiceRegistry.notificationHistoryRepository,
          pageSize: 10,
        );
    _scrollController = ScrollController()..addListener(_handleScroll);
    unawaited(_controller.bootstrap());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final items = _controller.items;

            if (_controller.isLoading && items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_controller.errorMessage != null &&
                items.isEmpty &&
                !_controller.isOffline) {
              return _NewsPageStateView(
                title: 'Не удалось загрузить уведомления',
                description: _controller.errorMessage!,
                actionLabel: 'Повторить',
                onActionTap: _controller.forceRefresh,
              );
            }

            if (_controller.isOffline && items.isEmpty) {
              return _NewsPageStateView(
                title: 'Нет соединения',
                description:
                    'Показаны последние данные после первой успешной загрузки.',
                actionLabel: 'Повторить',
                onActionTap: _controller.forceRefresh,
              );
            }

            if (items.isEmpty) {
              return const _NewsPageStateView(
                title: 'Пока нет уведомлений',
                description:
                    'История появится здесь, как только в приложении будут опубликованы новости.',
              );
            }

            return RefreshIndicator(
              onRefresh: _controller.forceRefresh,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(StarKidsSpacing.xl),
                itemCount: items.length + _extraItemCount,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: StarKidsSpacing.lg),
                itemBuilder: (context, index) {
                  if (_showBanner && index == 0) {
                    if (_controller.isOffline) {
                      return const _NewsInlineInfoCard(
                        title: 'Нет соединения',
                        description: 'Показаны последние данные',
                      );
                    }

                    return _NewsInlineErrorCard(
                      message: _controller.errorMessage!,
                      onRetry: _controller.forceRefresh,
                    );
                  }

                  final contentOffset = _showBanner ? 1 : 0;
                  final itemIndex = index - contentOffset;

                  if (itemIndex >= 0 && itemIndex < items.length) {
                    final item = items[itemIndex];
                    return _NewsListCard(
                      item: item,
                      onTap: item.opensNewsDetails
                          ? () => _openNotification(item)
                          : null,
                    );
                  }

                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: StarKidsSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  bool get _showBanner {
    return _controller.isOffline ||
        (_controller.errorMessage != null && !_controller.isOffline);
  }

  int get _extraItemCount {
    return (_showBanner ? 1 : 0) + (_controller.isLoadingMore ? 1 : 0);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      unawaited(_controller.loadMore());
    }
  }

  void _openNotification(AppNotification item) {
    final newsId = item.newsId?.trim() ?? '';
    if (newsId.isEmpty) {
      return;
    }

    unawaited(
      ServiceRegistry.newsRepository.trackNewsEvent(
        newsId: newsId,
        eventType: NewsEventType.click,
      ),
    );
    Navigator.of(context).pushNamed(
      AppRoutes.newsDetails,
      arguments: NewsDetailsPageArgs(
        newsId: newsId,
        initialItem: NewsItem(
          id: newsId,
          title: item.title,
          imageUrl: item.imageUrl ?? '',
          description: item.description,
          createdAt: item.createdAt,
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
            'Не удалось обновить историю',
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

class _NewsInlineInfoCard extends StatelessWidget {
  const _NewsInlineInfoCard({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
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

class _NewsListCard extends StatelessWidget {
  const _NewsListCard({
    required this.item,
    this.onTap,
  });

  final AppNotification item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final imageUrl = resolveNewsImageUrl(item.imageUrl ?? '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
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
                      const SizedBox(height: StarKidsSpacing.xs),
                      Text(
                        _typeLabel(item.type),
                        style: textTheme.labelSmall?.copyWith(
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

  String _typeLabel(NotificationType value) {
    switch (value) {
      case NotificationType.system:
        return 'Системное уведомление';
      case NotificationType.promo:
        return 'Промо';
      case NotificationType.news:
        return 'Новость';
    }
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
