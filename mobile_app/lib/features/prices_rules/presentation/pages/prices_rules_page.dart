import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_media_image.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../branches/domain/branch_option.dart';
import '../../data/prices_rules_curated_content.dart';
import '../../domain/branch_prices_rules.dart';

class PricesRulesPage extends StatelessWidget {
  const PricesRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Цены и правила'),
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
              label: 'Посмотреть пакеты праздника',
              icon: Icons.cake_rounded,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.birthdays),
            ),
          ),
          body: FutureBuilder<_PricesRulesScreenData>(
            future: _loadScreenData(branch.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const StarKidsContentSwitcher(
                  child: Center(
                    key: ValueKey('prices-rules-loading'),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return StarKidsContentSwitcher(
                  child: _PricesRulesStateView(
                    key: const ValueKey('prices-rules-error'),
                    title: 'Цены пока недоступны',
                    description:
                        'Не удалось показать тарифы и правила для выбранного филиала. Попробуйте выбрать другой филиал.',
                    actionLabel: 'Сменить филиал',
                    onActionTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.branchSelection),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return StarKidsContentSwitcher(
                  child: _PricesRulesStateView(
                    key: const ValueKey('prices-rules-empty'),
                    title: 'Цены пока недоступны',
                    description:
                        'Экран готов, но тарифы и правила для этого филиала пока не удалось показать.',
                    actionLabel: 'Сменить филиал',
                    onActionTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.branchSelection),
                  ),
                );
              }

              final data = snapshot.data!.pricesRules;
              final resolvedBranch = snapshot.data!.branch;
              final textTheme = Theme.of(context).textTheme;
              final introTitle = data.introTitle.trim().isNotEmpty
                  ? data.introTitle.trim()
                  : 'Цены и правила';
              final introDescription = data.introDescription.trim().isNotEmpty
                  ? data.introDescription.trim()
                  : 'Актуальные условия посещения для выбранного филиала появятся здесь.';
              final birthdayNote = data.birthdayNote.trim().isNotEmpty
                  ? data.birthdayNote.trim()
                  : 'Детали по формату дня рождения можно уточнить у менеджера после выбора пакета.';
              final tariffGroups = _groupTariffs(data.visitTariffs);

              return StarKidsContentSwitcher(
                child: ListView(
                  key: ValueKey('prices-rules-loaded-${resolvedBranch.id}'),
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
                              color: StarKidsColors.surfaceTertiary,
                              borderRadius: BorderRadius.circular(
                                StarKidsRadii.full,
                              ),
                            ),
                            child: Text(
                              resolvedBranch.shortLabel,
                              style: textTheme.labelMedium?.copyWith(
                                color: StarKidsColors.brandPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: StarKidsSpacing.md),
                          Text(introTitle, style: textTheme.headlineMedium),
                          const SizedBox(height: StarKidsSpacing.md),
                          Text(introDescription, style: textTheme.bodyLarge),
                        ],
                      ),
                    ),
                    const SizedBox(height: StarKidsSpacing.x2l),
                    const StarKidsSectionHeader(
                      title: 'Тарифы посещения',
                      description:
                          'Полный прайс без сокращений и без формулировок вида «от ...».',
                    ),
                    const SizedBox(height: StarKidsSpacing.lg),
                    if (data.visitTariffs.isNotEmpty)
                      if (tariffGroups.length > 1)
                        ...tariffGroups.map(
                          (group) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: StarKidsSpacing.md,
                            ),
                            child: _TariffGroupCard(group: group),
                          ),
                        )
                      else
                        ...data.visitTariffs.map(
                          (tariff) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: StarKidsSpacing.md,
                            ),
                            child: _TariffCard(tariff: tariff),
                          ),
                        )
                    else
                      const _InlineInfoCard(
                        title: 'Тарифы скоро появятся',
                        description:
                            'Для этого филиала еще не опубликован список тарифов. Базовые детали можно уточнить у менеджера.',
                      ),
                    if (data.menuSections.isNotEmpty) ...[
                      const SizedBox(height: StarKidsSpacing.x2l),
                      const StarKidsSectionHeader(
                        title: 'Меню',
                        description:
                            'Большой блок меню прямо внутри экрана: заметные категории, понятные цены и аккуратные изображения.',
                      ),
                      const SizedBox(height: StarKidsSpacing.lg),
                      const _FeatureIntroCard(
                        title: 'Меню кафе',
                        description:
                            'Секции не спрятаны в мелкие элементы: каждая категория раскрыта сразу, а цены видны без дополнительных переходов.',
                        icon: Icons.restaurant_menu_rounded,
                        tintColor: StarKidsColors.surfaceSecondary,
                      ),
                      const SizedBox(height: StarKidsSpacing.lg),
                      ...data.menuSections.map(
                        (section) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: StarKidsSpacing.lg,
                          ),
                          child: _MenuSectionCard(section: section),
                        ),
                      ),
                    ],
                    if (data.birthdayPackages.isNotEmpty) ...[
                      const SizedBox(height: StarKidsSpacing.x2l),
                      const StarKidsSectionHeader(
                        title: 'Пакеты дней рождения',
                        description:
                            'Отдельный важный блок с точной ценой в тенге, старой ценой и полным составом каждого пакета.',
                      ),
                      const SizedBox(height: StarKidsSpacing.lg),
                      const _FeatureIntroCard(
                        title: 'Праздничные пакеты',
                        description:
                            'Здесь показаны все ключевые услуги внутри пакета, чтобы родитель сразу видел разницу между сценариями.',
                        icon: Icons.celebration_rounded,
                        tintColor: StarKidsColors.surfaceTertiary,
                      ),
                      const SizedBox(height: StarKidsSpacing.lg),
                      ...data.birthdayPackages.map(
                        (package) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: StarKidsSpacing.lg,
                          ),
                          child: _BirthdayPackageOfferCard(package: package),
                        ),
                      ),
                      StarKidsButton.secondary(
                        label: 'Открыть отдельный раздел праздников',
                        icon: Icons.cake_rounded,
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.birthdays),
                      ),
                    ],
                    const SizedBox(height: StarKidsSpacing.x2l),
                    const StarKidsSectionHeader(
                      title: 'Льготы и важные условия',
                      description:
                          'Короткий список важных условий и бесплатных льгот без перегруза длинным регламентом.',
                    ),
                    const SizedBox(height: StarKidsSpacing.md),
                    if (data.rules.isNotEmpty)
                      ...data.rules.map(
                        (rule) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: StarKidsSpacing.md,
                          ),
                          child: _RuleRow(rule: rule),
                        ),
                      )
                    else
                      const _InlineInfoCard(
                        title: 'Правила скоро появятся',
                        description:
                            'Основные правила посещения для этого филиала обновляются. Их можно уточнить перед визитом.',
                      ),
                    const SizedBox(height: StarKidsSpacing.xl),
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
                            'Если нужен другой формат праздника',
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: StarKidsSpacing.sm),
                          Text(birthdayNote, style: textTheme.bodyLarge),
                        ],
                      ),
                    ),
                    if (data.disclaimer != null) ...[
                      const SizedBox(height: StarKidsSpacing.lg),
                      Text(
                        data.disclaimer!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: StarKidsColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<_PricesRulesScreenData> _loadScreenData(String branchId) async {
    final branch = await ServiceRegistry.branchRepository
        .getBranch(branchId)
        .catchError(
          (_) => ServiceRegistry.selectedBranchController.selectedBranch,
        );
    ServiceRegistry.selectedBranchController.syncSelectedBranch(branch);
    final pricesRules = await ServiceRegistry.pricesRulesRepository
        .getForBranch(branchId);

    return _PricesRulesScreenData(
      branch: branch,
      pricesRules: applyCuratedPricesRulesContent(
        branch: branch,
        source: pricesRules,
      ),
    );
  }

  List<_TariffGroupData> _groupTariffs(List<VisitTariff> tariffs) {
    if (tariffs.isEmpty) {
      return const [];
    }

    final grouped = <String, List<_TariffGroupItemData>>{};

    for (final tariff in tariffs) {
      final parts = tariff.title.split('·');
      if (parts.length < 2) {
        return const [];
      }

      final groupTitle = parts.first.trim();
      final itemTitle = parts.sublist(1).join('·').trim();
      grouped
          .putIfAbsent(groupTitle, () => <_TariffGroupItemData>[])
          .add(
            _TariffGroupItemData(
              title: itemTitle,
              priceLabel: tariff.priceLabel,
              description: tariff.description,
            ),
          );
    }

    return grouped.entries
        .map((entry) => _TariffGroupData(title: entry.key, items: entry.value))
        .toList(growable: false);
  }
}

class _TariffCard extends StatelessWidget {
  const _TariffCard({required this.tariff});

  final VisitTariff tariff;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;

        return Container(
          padding: const EdgeInsets.all(StarKidsSpacing.lg),
          decoration: BoxDecoration(
            color: StarKidsColors.surfacePrimary,
            borderRadius: BorderRadius.circular(StarKidsRadii.xl),
            border: Border.all(color: StarKidsColors.borderDefault),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
                Text(tariff.title, style: textTheme.titleLarge),
                const SizedBox(height: StarKidsSpacing.sm),
                _PriceChip(label: tariff.priceLabel),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(tariff.title, style: textTheme.titleLarge),
                    ),
                    const SizedBox(width: StarKidsSpacing.md),
                    _PriceChip(label: tariff.priceLabel),
                  ],
                ),
              const SizedBox(height: StarKidsSpacing.sm),
              Text(tariff.description, style: textTheme.bodyMedium),
            ],
          ),
        );
      },
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule});

  final String rule;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: StarKidsColors.brandSecondary,
          ),
        ),
        const SizedBox(width: StarKidsSpacing.sm),
        Expanded(
          child: Text(rule, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class _PricesRulesStateView extends StatelessWidget {
  const _PricesRulesStateView({
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

class _PricesRulesScreenData {
  const _PricesRulesScreenData({
    required this.branch,
    required this.pricesRules,
  });

  final BranchOption branch;
  final BranchPricesRules pricesRules;
}

class _InlineInfoCard extends StatelessWidget {
  const _InlineInfoCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(color: StarKidsColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _FeatureIntroCard extends StatelessWidget {
  const _FeatureIntroCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.tintColor,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color tintColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: tintColor,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: StarKidsColors.surfacePrimary,
              borderRadius: BorderRadius.circular(StarKidsRadii.full),
            ),
            child: Icon(icon, color: StarKidsColors.brandPrimary),
          ),
          const SizedBox(width: StarKidsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleLarge),
                const SizedBox(height: StarKidsSpacing.xs),
                Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: StarKidsColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSectionCard extends StatelessWidget {
  const _MenuSectionCard({required this.section});

  final MenuSection section;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(color: StarKidsColors.borderDefault),
        boxShadow: StarKidsShadows.depth1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.imageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 8,
              child: StarKidsMediaImage(source: section.imageUrl),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              StarKidsSpacing.lg,
              StarKidsSpacing.lg,
              StarKidsSpacing.lg,
              StarKidsSpacing.lg,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useVerticalHeader = constraints.maxWidth < 360;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (useVerticalHeader)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(section.title, style: textTheme.headlineSmall),
                          if (section.subtitle != null) ...[
                            const SizedBox(height: StarKidsSpacing.sm),
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
                                section.subtitle!,
                                style: textTheme.labelMedium?.copyWith(
                                  color: StarKidsColors.brandPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              section.title,
                              style: textTheme.headlineSmall,
                            ),
                          ),
                          if (section.subtitle != null) ...[
                            const SizedBox(width: StarKidsSpacing.md),
                            Flexible(
                              child: Container(
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
                                  section.subtitle!,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: StarKidsColors.brandPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: StarKidsSpacing.sm),
                    Text(
                      'Все позиции показаны сразу: можно быстро сравнить блюда и цены в одной категории.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: StarKidsColors.textSecondary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              StarKidsSpacing.lg,
              0,
              StarKidsSpacing.lg,
              StarKidsSpacing.lg,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 720;
                final cardWidth = useTwoColumns
                    ? (constraints.maxWidth - StarKidsSpacing.md) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: StarKidsSpacing.md,
                  runSpacing: StarKidsSpacing.md,
                  children: section.items
                      .map(
                        (item) => SizedBox(
                          width: cardWidth,
                          child: _MenuItemCard(item: item),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StarKidsSpacing.md),
      decoration: BoxDecoration(
        color: StarKidsColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(StarKidsRadii.md),
            child: SizedBox(
              width: 76,
              height: 76,
              child: StarKidsMediaImage(source: item.imageUrl),
            ),
          ),
          const SizedBox(width: StarKidsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: textTheme.titleMedium),
                const SizedBox(height: StarKidsSpacing.sm),
                _PriceChip(label: item.priceLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayPackageOfferCard extends StatelessWidget {
  const _BirthdayPackageOfferCard({required this.package});

  final BirthdayPackageOffer package;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isFeatured = package.badgeLabel == 'Самый популярный';

    return Container(
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(
          color: isFeatured
              ? StarKidsColors.brandPrimary
              : StarKidsColors.borderDefault,
        ),
        boxShadow: StarKidsShadows.depth1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: StarKidsMediaImage(source: package.imagePath),
          ),
          Padding(
            padding: const EdgeInsets.all(StarKidsSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StarKidsSpacing.md,
                    vertical: StarKidsSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isFeatured
                        ? StarKidsColors.surfaceTertiary
                        : StarKidsColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(StarKidsRadii.full),
                  ),
                  child: Text(
                    package.badgeLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: isFeatured
                          ? StarKidsColors.brandPrimary
                          : StarKidsColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: StarKidsSpacing.md),
                Text(package.title, style: textTheme.headlineSmall),
                const SizedBox(height: StarKidsSpacing.xs),
                Text(
                  package.subtitle,
                  style: textTheme.bodyLarge?.copyWith(
                    color: StarKidsColors.textSecondary,
                  ),
                ),
                const SizedBox(height: StarKidsSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(StarKidsSpacing.lg),
                  decoration: BoxDecoration(
                    color: StarKidsColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(StarKidsRadii.lg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Старая цена',
                        style: textTheme.labelMedium?.copyWith(
                          color: StarKidsColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: StarKidsSpacing.xs),
                      Text(
                        package.oldPriceLabel,
                        style: textTheme.titleLarge?.copyWith(
                          color: StarKidsColors.textSecondary,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: StarKidsSpacing.md),
                      Text(
                        'В рабочие дни',
                        style: textTheme.labelMedium?.copyWith(
                          color: StarKidsColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: StarKidsSpacing.xs),
                      _PriceChip(label: package.weekdayPriceLabel),
                    ],
                  ),
                ),
                const SizedBox(height: StarKidsSpacing.lg),
                ...package.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: StarKidsSpacing.md),
                    child: _BirthdayPackageFeatureRow(feature: feature),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayPackageFeatureRow extends StatelessWidget {
  const _BirthdayPackageFeatureRow({required this.feature});

  final BirthdayPackageFeature feature;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: StarKidsColors.brandSecondary,
          ),
        ),
        const SizedBox(width: StarKidsSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(feature.title, style: textTheme.titleMedium),
              if (feature.details != null) ...[
                const SizedBox(height: StarKidsSpacing.xs),
                Text(
                  feature.details!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: StarKidsColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TariffGroupCard extends StatelessWidget {
  const _TariffGroupCard({required this.group});

  final _TariffGroupData group;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
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
          Text(group.title, style: textTheme.headlineSmall),
          const SizedBox(height: StarKidsSpacing.md),
          ...group.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: StarKidsSpacing.md),
              child: _TariffGroupItemCard(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _TariffGroupItemCard extends StatelessWidget {
  const _TariffGroupItemCard({required this.item});

  final _TariffGroupItemData item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StarKidsSpacing.md),
      decoration: BoxDecoration(
        color: StarKidsColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(item.title, style: textTheme.titleMedium)),
              const SizedBox(width: StarKidsSpacing.md),
              _PriceChip(label: item.priceLabel),
            ],
          ),
          if (item.description.trim().isNotEmpty) ...[
            const SizedBox(height: StarKidsSpacing.sm),
            Text(
              item.description,
              style: textTheme.bodyMedium?.copyWith(
                color: StarKidsColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StarKidsSpacing.md,
        vertical: StarKidsSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: StarKidsColors.brandHighlight,
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: StarKidsColors.textPrimary),
      ),
    );
  }
}

class _TariffGroupData {
  const _TariffGroupData({required this.title, required this.items});

  final String title;
  final List<_TariffGroupItemData> items;
}

class _TariffGroupItemData {
  const _TariffGroupItemData({
    required this.title,
    required this.priceLabel,
    required this.description,
  });

  final String title;
  final String priceLabel;
  final String description;
}
