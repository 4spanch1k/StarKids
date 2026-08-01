import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/star_kids_media_image.dart';
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
      appBar: GlassAppBar(
        leading: GlassIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Уведомления',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
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
              return _NotificationsStateView(
                title: 'Не удалось загрузить уведомления',
                description: _controller.errorMessage!,
                actionLabel: 'Повторить',
                onActionTap: _controller.forceRefresh,
              );
            }

            if (_controller.isOffline && items.isEmpty) {
              return _NotificationsStateView(
                title: 'Нет соединения',
                description:
                    'Показаны последние данные после первой успешной загрузки.',
                actionLabel: 'Повторить',
                onActionTap: _controller.forceRefresh,
              );
            }

            if (items.isEmpty) {
              return const _NotificationsStateView(
                title: 'Пока нет уведомлений',
                description:
                    'История появится здесь, как только в приложении будут опубликованы новости.',
              );
            }

            return RefreshIndicator(
              onRefresh: _controller.forceRefresh,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(SKSpacing.x5),
                itemCount: items.length + _extraItemCount,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: SKSpacing.x4),
                itemBuilder: (context, index) {
                  if (_showBanner && index == 0) {
                    if (_controller.isOffline) {
                      return const _NotificationsInlineInfoCard(
                        title: 'Нет соединения',
                        description: 'Показаны последние данные',
                      );
                    }

                    return _NotificationsInlineErrorCard(
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
                    padding: EdgeInsets.symmetric(vertical: SKSpacing.x3),
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

class _NotificationsStateView extends StatelessWidget {
  const _NotificationsStateView({
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
    final c = SKTheme.of(context).colors;

    return Center(
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
              Text(description, style: Theme.of(context).textTheme.bodyLarge),
              if (actionLabel != null && onActionTap != null) ...[
                const SizedBox(height: SKSpacing.x5),
                PrimaryButton(
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

class _NotificationsInlineErrorCard extends StatelessWidget {
  const _NotificationsInlineErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.all(SKSpacing.x4),
      decoration: BoxDecoration(
        color: c.dangerSoft,
        borderRadius: BorderRadius.circular(SKRadius.lg),
        border: Border.all(color: c.danger.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Не удалось обновить историю',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SKSpacing.x1),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: SKSpacing.x3),
          SecondaryButton(
            label: 'Повторить',
            onPressed: () => onRetry(),
          ),
        ],
      ),
    );
  }
}

class _NotificationsInlineInfoCard extends StatelessWidget {
  const _NotificationsInlineInfoCard({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Container(
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
    final c = SKTheme.of(context).colors;
    final imageUrl = resolveNewsImageUrl(item.imageUrl ?? '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SKRadius.lg),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: c.elevated,
            borderRadius: BorderRadius.circular(SKRadius.lg),
            border: Border.all(color: c.hairline, width: 0.5),
            boxShadow: SKShadows.sm,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SKRadius.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: StarKidsMediaImage(
                    source: imageUrl,
                    fallbackSource: 'assets/images/home_hero.jpg',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(SKSpacing.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(item.createdAt),
                        style: textTheme.labelMedium?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: SKSpacing.x1),
                      Text(
                        _typeLabel(item.type),
                        style: textTheme.labelSmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: SKSpacing.x2),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge,
                      ),
                      if ((item.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: SKSpacing.x2),
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
