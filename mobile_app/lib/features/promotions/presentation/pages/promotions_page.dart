import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/widgets/star_kids_root_navigation.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/glass_floating_button.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/star_kids_content_block_card.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_promo_card.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../../core/design_system/widgets/stable_future_builder.dart';
import '../../../../core/design_system/widgets/star_kids_media_image.dart';
import '../../../branches/domain/branch_option.dart';
import '../../../content/domain/public_content_block.dart';
import '../../../requests/domain/request_type.dart';
import '../../../requests/presentation/models/request_page_args.dart';
import '../../domain/promotion_offer.dart';

class PromotionsPage extends StatelessWidget {
  const PromotionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;

        return Scaffold(
          extendBody: true,
          appBar: GlassAppBar(
            leading: const SizedBox(width: 44),
            title: Text(
              'Акции',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: GlassIconButton(
              icon: Icons.swap_horiz_rounded,
              tooltip: 'Сменить филиал',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.branchSelection),
            ),
          ),
          bottomNavigationBar:
              const StarKidsRootNavigation(current: 'promotions'),
          body: Stack(
            children: [
              StableFutureBuilder<_PromotionsScreenData>(
                cacheKey: branch.id,
                futureFactory: () => _loadScreenData(branch.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const StarKidsContentSwitcher(
                      child: Center(
                        key: ValueKey('promotions-loading'),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return StarKidsContentSwitcher(
                      child: _PromotionsStateView(
                        key: const ValueKey('promotions-error'),
                        title: 'Акции пока недоступны',
                        description:
                            'Не удалось загрузить коммерческие предложения. Попробуйте открыть экран позже.',
                        actionLabel: 'Выбрать другой филиал',
                        onActionTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.branchSelection),
                      ),
                    );
                  }

                  final data = snapshot.data ??
                      _PromotionsScreenData(
                        branch: branch,
                        promotions: <PromotionOffer>[],
                        contentBlocks: <PublicContentBlock>[],
                      );
                  final promotions = data.promotions;
                  if (promotions.isEmpty) {
                    return StarKidsContentSwitcher(
                      child: _PromotionsStateView(
                        key: const ValueKey('promotions-empty'),
                        title: 'Скоро появятся новые предложения',
                        description:
                            'Экран уже готов для коммерческого контента, но по текущему филиалу пока нет активных офферов.',
                        actionLabel: 'Сменить филиал',
                        onActionTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.branchSelection),
                      ),
                    );
                  }

                  final textTheme = Theme.of(context).textTheme;

                  return StarKidsContentSwitcher(
                    child: ListView(
                      key: ValueKey('promotions-loaded-${data.branch.id}'),
                      padding: EdgeInsets.fromLTRB(
                        SKSpacing.x5,
                        SKSpacing.x4,
                        SKSpacing.x5,
                        MediaQuery.viewPaddingOf(context).bottom + 88,
                      ),
                      children: [
                        _PromotionsHero(branch: data.branch),
                        const SizedBox(height: SKSpacing.x6),
                        StarKidsSectionHeader(
                          title: 'Предложения для ${data.branch.shortLabel}',
                          description:
                              'Коммерческий экран должен быстро показать, почему сюда стоит вернуться именно сейчас.',
                        ),
                        const SizedBox(height: SKSpacing.x4),
                        ...promotions.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: SKSpacing.x4,
                                ),
                                child: StarKidsPromoCard(
                                  revealDelay: starKidsStaggerDelay(entry.key),
                                  title: entry.value.title,
                                  description: entry.value.description,
                                  imagePath: entry.value.imagePath,
                                  badgeLabel: entry.value.badgeLabel,
                                  actionLabel: entry.value.ctaLabel,
                                  onTap: () => Navigator.of(context).pushNamed(
                                    AppRoutes.requests,
                                    arguments: const RequestPageArgs(
                                      initialType: RequestType.birthdayRequest,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        const SizedBox(height: SKSpacing.x4),
                        if (data.contentBlocks.isNotEmpty)
                          ...data.contentBlocks.asMap().entries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: SKSpacing.x3,
                                  ),
                                  child: StarKidsContentBlockCard(
                                    revealDelay:
                                        starKidsStaggerDelay(entry.key),
                                    title: entry.value.title,
                                    body: entry.value.body,
                                    label: entry.value.ctaLabel,
                                  ),
                                ),
                              )
                        else
                          SolidCard(
                            padding: const EdgeInsets.all(SKSpacing.x4),
                            radius: SKRadius.xl,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Зачем открывать приложение снова',
                                  style: textTheme.titleLarge,
                                ),
                                const SizedBox(height: SKSpacing.x2),
                                Text(
                                  'Филиалы, акции и birthday flow уже собраны в один сценарий: посмотреть, выбрать и оставить заявку за пару минут.',
                                  style: textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: GlassFloatingButton(
                    label: 'Оставить заявку на праздник',
                    icon: Icons.chat_bubble_rounded,
                    margin: const EdgeInsets.fromLTRB(
                      SKSpacing.gutter,
                      0,
                      SKSpacing.gutter,
                      SKSpacing.x3,
                    ),
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRoutes.requests,
                      arguments: const RequestPageArgs(
                        initialType: RequestType.birthdayRequest,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_PromotionsScreenData> _loadScreenData(String branchId) async {
    final branchFuture =
        ServiceRegistry.branchRepository.getBranch(branchId).catchError(
              (_) => ServiceRegistry.selectedBranchController.selectedBranch,
            );
    final promotionsFuture = ServiceRegistry.promotionRepository
        .listPromotions(branchId)
        .catchError((_) => const <PromotionOffer>[]);
    final contentBlocksFuture = ServiceRegistry.publicContentRepository
        .listContentBlocks(surface: 'promotions')
        .catchError((_) => const <PublicContentBlock>[]);

    final branch = await branchFuture;
    final promotions = await promotionsFuture;
    final contentBlocks = await contentBlocksFuture;
    ServiceRegistry.selectedBranchController.syncSelectedBranch(branch);

    return _PromotionsScreenData(
      branch: branch,
      promotions: promotions,
      contentBlocks: contentBlocks,
    );
  }
}

class _PromotionsHero extends StatelessWidget {
  const _PromotionsHero({required this.branch});

  final BranchOption branch;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(SKRadius.xl),
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const StarKidsMediaImage(
              source: 'assets/images/promo_hero.jpg',
              fallbackSource: 'assets/images/home_hero_generated.png',
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.textPrimary.withValues(alpha: 0.05),
                    c.textPrimary.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(SKSpacing.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    branch.shortLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                        ),
                  ),
                  const SizedBox(height: SKSpacing.x1),
                  Text(
                    'Предложения для вашего визита',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromotionsStateView extends StatelessWidget {
  const _PromotionsStateView({
    super.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SKSpacing.x5),
        child: Center(
          child: SolidCard(
            padding: const EdgeInsets.all(SKSpacing.x5),
            radius: SKRadius.xl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(SKRadius.lg),
                  child: const AspectRatio(
                    aspectRatio: 16 / 7,
                    child: StarKidsMediaImage(
                      source: 'assets/images/promo_hero.jpg',
                    ),
                  ),
                ),
                const SizedBox(height: SKSpacing.x4),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: SKSpacing.x2),
                Text(description, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: SKSpacing.x4),
                SecondaryButton(
                  label: actionLabel,
                  icon: Icons.swap_horiz_rounded,
                  onPressed: onActionTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromotionsScreenData {
  const _PromotionsScreenData({
    required this.branch,
    required this.promotions,
    required this.contentBlocks,
  });

  final BranchOption branch;
  final List<PromotionOffer> promotions;
  final List<PublicContentBlock> contentBlocks;
}
