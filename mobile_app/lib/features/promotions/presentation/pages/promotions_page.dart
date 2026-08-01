import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
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
            leading: GlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Назад',
              onPressed: () => Navigator.of(context).pop(),
            ),
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
          body: Stack(
            children: [
              FutureBuilder<_PromotionsScreenData>(
                future: _loadScreenData(branch.id),
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
                  final c = SKTheme.of(context).colors;

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
                        SolidCard(
                          padding: const EdgeInsets.all(SKSpacing.x5),
                          radius: SKRadius.xl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SKSpacing.x3,
                                  vertical: SKSpacing.x2,
                                ),
                                decoration: BoxDecoration(
                                  color: c.accentSoft,
                                  borderRadius:
                                      BorderRadius.circular(SKRadius.pill),
                                ),
                                child: Text(
                                  data.branch.shortLabel,
                                  style: SKTextStyles.micro.copyWith(
                                    color: c.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: SKSpacing.x3),
                              Text(
                                'Акции должны возвращать родителя в приложение, а не просто висеть как баннер.',
                                style: textTheme.headlineMedium,
                              ),
                              const SizedBox(height: SKSpacing.x3),
                              Text(
                                'Здесь собраны branch-aware офферы и удобный вход в request flow без нового визуального шума.',
                                style: textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
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
    final branch =
        await ServiceRegistry.branchRepository.getBranch(branchId).catchError(
              (_) => ServiceRegistry.selectedBranchController.selectedBranch,
            );
    ServiceRegistry.selectedBranchController.syncSelectedBranch(branch);
    final promotions = await ServiceRegistry.promotionRepository
        .listPromotions(branchId)
        .catchError((_) => const <PromotionOffer>[]);
    final contentBlocks = await ServiceRegistry.publicContentRepository
        .listContentBlocks(surface: 'promotions')
        .catchError((_) => const <PublicContentBlock>[]);

    return _PromotionsScreenData(
      branch: branch,
      promotions: promotions,
      contentBlocks: contentBlocks,
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
