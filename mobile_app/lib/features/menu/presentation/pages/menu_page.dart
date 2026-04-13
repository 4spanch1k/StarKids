import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_media_image.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../branches/domain/branch_option.dart';
import '../../domain/branch_menu.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Меню'),
            actions: [
              IconButton(
                tooltip: 'Сменить филиал',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.branchSelection),
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
            ],
          ),
          body: FutureBuilder<_MenuScreenData>(
            future: _loadScreenData(branch.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const StarKidsContentSwitcher(
                  child: Center(
                    key: ValueKey('menu-loading'),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return StarKidsContentSwitcher(
                  child: _MenuStateView(
                    key: const ValueKey('menu-error'),
                    title: 'Меню пока недоступно',
                    description:
                        'Не удалось загрузить позиции для выбранного филиала. Попробуйте выбрать другой филиал или зайти позже.',
                    actionLabel: 'Сменить филиал',
                    onActionTap: () => Navigator.of(context)
                        .pushNamed(AppRoutes.branchSelection),
                  ),
                );
              }

              final data = snapshot.data!;
              final textTheme = Theme.of(context).textTheme;

              if (data.menu.categories.isEmpty) {
                return StarKidsContentSwitcher(
                  child: _MenuStateView(
                    key: const ValueKey('menu-empty'),
                    title: 'Меню скоро появится',
                    description:
                        'Для этого филиала еще не опубликованы блюда. Попробуйте открыть другой филиал.',
                    actionLabel: 'Сменить филиал',
                    onActionTap: () => Navigator.of(context)
                        .pushNamed(AppRoutes.branchSelection),
                  ),
                );
              }

              return StarKidsContentSwitcher(
                child: ListView(
                  key: ValueKey('menu-loaded-${data.branch.id}'),
                  padding: const EdgeInsets.fromLTRB(
                    StarKidsSpacing.xl,
                    StarKidsSpacing.lg,
                    StarKidsSpacing.xl,
                    StarKidsSpacing.x4l,
                  ),
                  children: [
                    StarKidsReveal(
                      child: Container(
                        padding: const EdgeInsets.all(StarKidsSpacing.xl),
                        decoration: BoxDecoration(
                          color: StarKidsColors.surfacePrimary,
                          borderRadius: BorderRadius.circular(
                            StarKidsRadii.hero,
                          ),
                          border: Border.all(
                            color: StarKidsColors.borderDefault,
                          ),
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
                                color: StarKidsColors.surfaceTertiary,
                                borderRadius: BorderRadius.circular(
                                  StarKidsRadii.full,
                                ),
                              ),
                              child: Text(
                                data.branch.shortLabel,
                                style: textTheme.labelMedium?.copyWith(
                                  color: StarKidsColors.brandPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: StarKidsSpacing.md),
                            Text('Меню кафе', style: textTheme.headlineMedium),
                            const SizedBox(height: StarKidsSpacing.md),
                            Text(
                              'Все позиции, цены и картинки приходят из админки. Категории разделены так, чтобы меню было удобно читать на телефоне.',
                              style: textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: StarKidsSpacing.x2l),
                    const StarKidsReveal(
                      delay: Duration(milliseconds: 80),
                      child: StarKidsSectionHeader(
                        title: 'Категории',
                        description:
                            'Каждое блюдо показывает отдельную картинку и точную цену в тенге.',
                      ),
                    ),
                    const SizedBox(height: StarKidsSpacing.lg),
                    ...data.menu.categories.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: StarKidsSpacing.xl,
                            ),
                            child: _MenuCategoryCard(
                              revealDelay: starKidsStaggerDelay(entry.key),
                              category: entry.value,
                            ),
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<_MenuScreenData> _loadScreenData(String branchId) async {
    final branch =
        await ServiceRegistry.branchRepository.getBranch(branchId).catchError(
              (_) => ServiceRegistry.selectedBranchController.selectedBranch,
            );
    ServiceRegistry.selectedBranchController.syncSelectedBranch(branch);
    final menu = await ServiceRegistry.menuRepository.getForBranch(branchId);

    return _MenuScreenData(
      branch: branch,
      menu: menu,
    );
  }
}

class _MenuCategoryCard extends StatelessWidget {
  const _MenuCategoryCard({
    required this.category,
    this.revealDelay = Duration.zero,
  });

  final MenuCategory category;
  final Duration revealDelay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return StarKidsReveal(
      delay: revealDelay,
      child: Container(
        padding: const EdgeInsets.all(StarKidsSpacing.lg),
        decoration: BoxDecoration(
          color: StarKidsColors.surfacePrimary,
          borderRadius: BorderRadius.circular(StarKidsRadii.xl),
          border: Border.all(color: StarKidsColors.borderDefault),
          boxShadow: StarKidsShadows.depth1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: StarKidsColors.surfaceTertiary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: StarKidsColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: StarKidsSpacing.md),
                Expanded(
                  child: Text(
                    category.title,
                    style: textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            ...category.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: StarKidsSpacing.md),
                child: _MenuItemCard(item: item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
  });

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.md),
      decoration: BoxDecoration(
        color: StarKidsColors.surfaceCanvas,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 96,
              height: 96,
              child: StarKidsMediaImage(source: item.imageUrl),
            ),
          ),
          const SizedBox(width: StarKidsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: StarKidsSpacing.sm),
                Text(
                  _formatPrice(item.priceTenge),
                  style: textTheme.titleLarge?.copyWith(
                    color: StarKidsColors.brandPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int priceTenge) {
    return '$priceTenge тг';
  }
}

class _MenuStateView extends StatelessWidget {
  const _MenuStateView({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(StarKidsSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: StarKidsSpacing.md),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: StarKidsSpacing.lg),
            StarKidsButton.secondary(
              label: actionLabel,
              icon: Icons.swap_horiz_rounded,
              onPressed: onActionTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuScreenData {
  const _MenuScreenData({
    required this.branch,
    required this.menu,
  });

  final BranchOption branch;
  final BranchMenu menu;
}
