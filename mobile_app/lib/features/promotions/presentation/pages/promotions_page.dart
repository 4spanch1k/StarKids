import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_content_block_card.dart';
import '../../../../core/design_system/widgets/star_kids_promo_card.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../content/domain/public_content_block.dart';
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
          appBar: AppBar(
            title: const Text('Акции'),
            actions: [
              IconButton(
                tooltip: 'Сменить филиал',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.branchSelection),
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
            ],
          ),
          bottomNavigationBar: StarKidsBottomCtaBar(
            child: StarKidsButton.primary(
              label: 'Оставить заявку на праздник',
              icon: Icons.chat_bubble_rounded,
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.requests,
                arguments: const RequestPageArgs(),
              ),
            ),
          ),
          body: FutureBuilder<_PromotionsScreenData>(
            future: _loadScreenData(branch.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _PromotionsStateView(
                  title: 'Акции пока недоступны',
                  description:
                      'Не удалось загрузить коммерческие предложения. Попробуйте открыть экран позже.',
                  actionLabel: 'Выбрать другой филиал',
                  onActionTap: () => Navigator.of(context)
                      .pushNamed(AppRoutes.branchSelection),
                );
              }

              final data = snapshot.data ??
                  const _PromotionsScreenData(
                    promotions: <PromotionOffer>[],
                    contentBlocks: <PublicContentBlock>[],
                  );
              final promotions = data.promotions;
              if (promotions.isEmpty) {
                return _PromotionsStateView(
                  title: 'Скоро появятся новые предложения',
                  description:
                      'Экран уже готов для коммерческого контента, но по текущему филиалу пока нет активных офферов.',
                  actionLabel: 'Сменить филиал',
                  onActionTap: () => Navigator.of(context)
                      .pushNamed(AppRoutes.branchSelection),
                );
              }

              final textTheme = Theme.of(context).textTheme;

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  StarKidsSpacing.xl,
                  StarKidsSpacing.lg,
                  StarKidsSpacing.xl,
                  StarKidsSpacing.x5l,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(StarKidsSpacing.xl),
                    decoration: BoxDecoration(
                      color: StarKidsColors.surfacePrimary,
                      borderRadius: BorderRadius.circular(StarKidsRadii.hero),
                      border: Border.all(color: StarKidsColors.borderDefault),
                      boxShadow: StarKidsShadows.depth1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: StarKidsSpacing.md,
                            vertical: StarKidsSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: StarKidsColors.brandHighlight,
                            borderRadius:
                                BorderRadius.circular(StarKidsRadii.full),
                          ),
                          child: Text(
                            branch.shortLabel,
                            style: textTheme.labelMedium?.copyWith(
                              color: StarKidsColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: StarKidsSpacing.md),
                        Text(
                          'Акции должны возвращать родителя в приложение, а не просто висеть как баннер.',
                          style: textTheme.headlineMedium,
                        ),
                        const SizedBox(height: StarKidsSpacing.md),
                        Text(
                          'Здесь собраны branch-aware офферы и удобный вход в request flow без нового визуального шума.',
                          style: textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: StarKidsSpacing.x2l),
                  StarKidsSectionHeader(
                    title: 'Предложения для ${branch.shortLabel}',
                    description:
                        'Коммерческий экран должен быстро показать, почему сюда стоит вернуться именно сейчас.',
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  ...promotions.map(
                    (promotion) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: StarKidsSpacing.lg),
                      child: StarKidsPromoCard(
                        title: promotion.title,
                        description: promotion.description,
                        imagePath: promotion.imagePath,
                        badgeLabel: promotion.badgeLabel,
                        actionLabel: promotion.ctaLabel,
                        onTap: () => Navigator.of(context).pushNamed(
                          AppRoutes.requests,
                          arguments: const RequestPageArgs(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  if (data.contentBlocks.isNotEmpty)
                    ...data.contentBlocks.map(
                      (block) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: StarKidsSpacing.md),
                        child: StarKidsContentBlockCard(
                          title: block.title,
                          body: block.body,
                          label: block.ctaLabel,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(StarKidsSpacing.lg),
                      decoration: BoxDecoration(
                        color: StarKidsColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Зачем открывать приложение снова',
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: StarKidsSpacing.sm),
                          Text(
                            'Филиалы, акции и birthday flow уже собраны в один сценарий: посмотреть, выбрать и оставить заявку за пару минут.',
                            style: textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<_PromotionsScreenData> _loadScreenData(String branchId) async {
    final promotions = await ServiceRegistry.promotionRepository
        .listPromotions(branchId)
        .catchError((_) => const <PromotionOffer>[]);
    final contentBlocks = await ServiceRegistry.publicContentRepository
        .listContentBlocks(surface: 'promotions');

    return _PromotionsScreenData(
      promotions: promotions,
      contentBlocks: contentBlocks,
    );
  }
}

class _PromotionsStateView extends StatelessWidget {
  const _PromotionsStateView({
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
        padding: const EdgeInsets.all(StarKidsSpacing.xl),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(StarKidsSpacing.xl),
            decoration: BoxDecoration(
              color: StarKidsColors.surfacePrimary,
              borderRadius: BorderRadius.circular(StarKidsRadii.xl),
              border: Border.all(color: StarKidsColors.borderDefault),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: StarKidsSpacing.sm),
                Text(description, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: StarKidsSpacing.lg),
                StarKidsButton.secondary(
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
    required this.promotions,
    required this.contentBlocks,
  });

  final List<PromotionOffer> promotions;
  final List<PublicContentBlock> contentBlocks;
}
