import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
import '../../../../core/design_system/widgets/star_kids_birthday_package_card.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../branches/data/branch_seed_data.dart';
import '../../data/birthday_package_seed_data.dart';

class BirthdaysPage extends StatelessWidget {
  const BirthdaysPage({
    super.key,
    this.branchId,
  });

  final String? branchId;

  @override
  Widget build(BuildContext context) {
    final branch = getBranchById(branchId);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Дни рождения')),
      bottomNavigationBar: StarKidsBottomCtaBar(
        child: StarKidsButton.primary(
          label: 'Оставить заявку на праздник',
          icon: Icons.cake_rounded,
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.requests),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          StarKidsSpacing.xl,
          StarKidsSpacing.lg,
          StarKidsSpacing.xl,
          StarKidsSpacing.x5l,
        ),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(StarKidsRadii.hero),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset(
                    'assets/images/birthday_hero.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x1A171316),
                          StarKidsColors.overlayImageBottom,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: StarKidsSpacing.lg,
                  right: StarKidsSpacing.lg,
                  bottom: StarKidsSpacing.lg,
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
                          borderRadius: BorderRadius.circular(
                            StarKidsRadii.full,
                          ),
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
                        'Праздник, который удобно продать и легко организовать',
                        style: textTheme.displayLarge?.copyWith(
                          color: StarKidsColors.textInverse,
                        ),
                      ),
                      const SizedBox(height: StarKidsSpacing.md),
                      Text(
                        'Готовые пакеты, понятная ценность и быстрый переход к заявке без сложной логики.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: StarKidsColors.textInverse,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: StarKidsSpacing.x2l),
          const StarKidsSectionHeader(
            title: 'Почему родители выбирают этот формат',
            description:
                'Сначала показываем ценность, потом предложения. Так экран работает как коммерческий оффер.',
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          Wrap(
            spacing: StarKidsSpacing.sm,
            runSpacing: StarKidsSpacing.sm,
            children: birthdayValueHighlights
                .map(
                  (highlight) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StarKidsSpacing.md,
                      vertical: StarKidsSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: StarKidsColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      highlight,
                      style: textTheme.labelMedium?.copyWith(
                        color: StarKidsColors.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: StarKidsSpacing.x2l),
          const StarKidsSectionHeader(
            title: 'Пакеты для разных сценариев',
            description:
                'Пользователь должен быстро понять бюджет, формат и самый подходящий пакет.',
          ),
          const SizedBox(height: StarKidsSpacing.md),
          ...birthdayPackageSeedData.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: StarKidsSpacing.lg),
              child: StarKidsBirthdayPackageCard(
                title: item.name,
                priceLabel: item.priceLabel,
                guestLabel: item.guestLabel,
                description: item.description,
                highlights: item.highlights,
                imagePath: item.imagePath,
                isFeatured: item.isFeatured,
                onActionTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.requests),
              ),
            ),
          ),
          const StarKidsSectionHeader(
            title: 'Как принять решение быстрее',
            description:
                'Минимальный comparison-блок вместо перегруженной таблицы. Достаточно для MVP и хорошо продает.',
          ),
          const SizedBox(height: StarKidsSpacing.md),
          Container(
            padding: const EdgeInsets.all(StarKidsSpacing.lg),
            decoration: BoxDecoration(
              color: StarKidsColors.surfacePrimary,
              borderRadius: BorderRadius.circular(StarKidsRadii.xl),
              border: Border.all(color: StarKidsColors.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _ComparisonRow(
                  title: 'Нужен быстрый семейный праздник',
                  value: 'Выбирайте Spark Party',
                ),
                SizedBox(height: StarKidsSpacing.md),
                _ComparisonRow(
                  title: 'Нужен wow-эффект и шоу',
                  value: 'Лучше всего подойдет Star Show',
                ),
                SizedBox(height: StarKidsSpacing.md),
                _ComparisonRow(
                  title: 'Большая компания и семейный формат',
                  value: 'Идите в Family Day',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.labelMedium),
        const SizedBox(height: StarKidsSpacing.xs),
        Text(value, style: textTheme.bodyLarge),
      ],
    );
  }
}
