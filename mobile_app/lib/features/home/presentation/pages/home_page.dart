import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_icon_sizes.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_birthday_package_card.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_promo_card.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../birthdays/data/birthday_package_seed_data.dart';
import '../../../requests/presentation/models/request_page_args.dart';
import '../../data/home_promotion_seed_data.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;
        final featuredPackage = birthdayPackageSeedData.firstWhere(
          (item) => item.isFeatured,
          orElse: () => birthdayPackageSeedData.first,
        );
        final textTheme = Theme.of(context).textTheme;

        return Scaffold(
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              switch (index) {
                case 1:
                  Navigator.of(context).pushNamed(AppRoutes.birthdays);
                  break;
                case 2:
                  Navigator.of(context).pushNamed(AppRoutes.promotions);
                  break;
                case 3:
                  Navigator.of(context).pushNamed(AppRoutes.profile);
                  break;
                case 0:
                default:
                  break;
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_rounded),
                label: 'Главная',
              ),
              NavigationDestination(
                icon: Icon(Icons.cake_rounded),
                label: 'Праздники',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_offer_rounded),
                label: 'Акции',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_rounded),
                label: 'Профиль',
              ),
            ],
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    StarKidsSpacing.xl,
                    StarKidsSpacing.lg,
                    StarKidsSpacing.xl,
                    StarKidsSpacing.x2l,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        InkWell(
                          borderRadius:
                              BorderRadius.circular(StarKidsRadii.full),
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.branchSelection),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: StarKidsSpacing.lg,
                              vertical: StarKidsSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: StarKidsColors.surfacePrimary,
                              borderRadius: BorderRadius.circular(
                                StarKidsRadii.full,
                              ),
                              border: Border.all(
                                  color: StarKidsColors.borderDefault),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: StarKidsIconSizes.sm,
                                  color: StarKidsColors.brandPrimary,
                                ),
                                const SizedBox(width: StarKidsSpacing.sm),
                                Expanded(
                                  child: Text(
                                    branch.name,
                                    style: textTheme.labelLarge,
                                  ),
                                ),
                                const Icon(
                                  Icons.expand_more_rounded,
                                  color: StarKidsColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: StarKidsSpacing.lg),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(StarKidsRadii.hero),
                          child: Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: Image.asset(
                                  branch.heroImagePath,
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
                                        Color(0x24171316),
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
                                        'Любят дети - доверяют родители',
                                        style: textTheme.labelMedium?.copyWith(
                                          color: StarKidsColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: StarKidsSpacing.md),
                                    Text(
                                      'Яркий семейный отдых и дни рождения в Star Kids',
                                      style: textTheme.displayLarge?.copyWith(
                                        color: StarKidsColors.textInverse,
                                      ),
                                    ),
                                    const SizedBox(height: StarKidsSpacing.md),
                                    Text(
                                      'Выберите филиал, посмотрите пакеты и отправьте заявку без лишних шагов.',
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: StarKidsColors.textInverse,
                                      ),
                                    ),
                                    const SizedBox(height: StarKidsSpacing.lg),
                                    StarKidsButton.primary(
                                      label: 'Организовать день рождения',
                                      onPressed: () => Navigator.of(context)
                                          .pushNamed(AppRoutes.birthdays),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: StarKidsSpacing.x2l),
                        const StarKidsSectionHeader(
                          title: 'Быстрые действия',
                          description:
                              'Самые частые сценарии для родителей собраны в один блок.',
                        ),
                        const SizedBox(height: StarKidsSpacing.lg),
                        GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: StarKidsSpacing.md,
                          crossAxisSpacing: StarKidsSpacing.md,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.38,
                          children: [
                            _QuickActionTile(
                              icon: Icons.map_rounded,
                              title: 'Филиал и маршрут',
                              subtitle: 'Как доехать и что внутри',
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.branchDetails),
                            ),
                            _QuickActionTile(
                              icon: Icons.cake_rounded,
                              title: 'Дни рождения',
                              subtitle: 'Пакеты и быстрый запрос',
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.birthdays),
                            ),
                            _QuickActionTile(
                              icon: Icons.receipt_long_rounded,
                              title: 'Цены и правила',
                              subtitle: 'Тарифы и важные условия',
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.pricesRules),
                            ),
                            _QuickActionTile(
                              icon: Icons.pin_drop_rounded,
                              title: 'Контакты и маршрут',
                              subtitle: 'Звонок, WhatsApp и как доехать',
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.contacts),
                            ),
                            _QuickActionTile(
                              icon: Icons.local_offer_rounded,
                              title: 'Акции',
                              subtitle:
                                  'Текущие предложения и поводы вернуться',
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.promotions),
                            ),
                            _QuickActionTile(
                              icon: Icons.chat_bubble_rounded,
                              title: 'Оставить заявку',
                              subtitle: 'Связаться с менеджером',
                              onTap: () => Navigator.of(context).pushNamed(
                                AppRoutes.requests,
                                arguments: const RequestPageArgs(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: StarKidsSpacing.x2l),
                        StarKidsSectionHeader(
                          title: 'Главный пакет для праздника',
                          description:
                              'Готовое коммерческое предложение, которое проще всего продать из главного экрана.',
                          actionLabel: 'Все пакеты',
                          onActionTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.birthdays),
                        ),
                        const SizedBox(height: StarKidsSpacing.lg),
                        StarKidsBirthdayPackageCard(
                          title: featuredPackage.name,
                          priceLabel: featuredPackage.priceLabel,
                          guestLabel: featuredPackage.guestLabel,
                          description: featuredPackage.description,
                          highlights: featuredPackage.highlights,
                          imagePath: featuredPackage.imagePath,
                          isFeatured: featuredPackage.isFeatured,
                          onActionTap: () => Navigator.of(context).pushNamed(
                            AppRoutes.requests,
                            arguments: RequestPageArgs(
                              initialPackageId: featuredPackage.id,
                              initialPackage: featuredPackage,
                            ),
                          ),
                        ),
                        const SizedBox(height: StarKidsSpacing.x2l),
                        StarKidsSectionHeader(
                          title: 'Актуальные акции и поводы вернуться',
                          description:
                              'Лента офферов должна быть заметной, но не превращаться в шум.',
                        ),
                        const SizedBox(height: StarKidsSpacing.lg),
                        ...homePromotionSeedData.map(
                          (promotion) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: StarKidsSpacing.md),
                            child: StarKidsPromoCard(
                              title: promotion.title,
                              description: promotion.description,
                              imagePath: promotion.imagePath,
                              badgeLabel: promotion.badgeLabel,
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.promotions),
                            ),
                          ),
                        ),
                        const SizedBox(height: StarKidsSpacing.x2l),
                        const StarKidsSectionHeader(
                          title: 'Почему сюда удобно возвращаться',
                          description:
                              'Четкий trust-block для повторного визита и быстрой заявки.',
                        ),
                        const SizedBox(height: StarKidsSpacing.lg),
                        Container(
                          padding: const EdgeInsets.all(StarKidsSpacing.lg),
                          decoration: BoxDecoration(
                            color: StarKidsColors.surfacePrimary,
                            borderRadius:
                                BorderRadius.circular(StarKidsRadii.xl),
                            border:
                                Border.all(color: StarKidsColors.borderDefault),
                            boxShadow: StarKidsShadows.depth1,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Star Kids помогает быстро решить семейный досуг: выбрать филиал, понять условия и сразу перейти к празднику или заявке.',
                                style: textTheme.bodyLarge,
                              ),
                              const SizedBox(height: StarKidsSpacing.lg),
                              Wrap(
                                spacing: StarKidsSpacing.sm,
                                runSpacing: StarKidsSpacing.sm,
                                children:
                                    branch.facilities.take(4).map((facility) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: StarKidsSpacing.md,
                                      vertical: StarKidsSpacing.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: StarKidsColors.surfaceSecondary,
                                      borderRadius: BorderRadius.circular(
                                        StarKidsRadii.full,
                                      ),
                                    ),
                                    child: Text(
                                      facility,
                                      style: textTheme.labelMedium?.copyWith(
                                        color: StarKidsColors.textPrimary,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: StarKidsSpacing.lg),
                              Row(
                                children: [
                                  Expanded(
                                    child: _TrustStat(
                                      title: '3000 кв.м',
                                      subtitle: 'пространства для активности',
                                    ),
                                  ),
                                  const SizedBox(width: StarKidsSpacing.md),
                                  Expanded(
                                    child: _TrustStat(
                                      title: branch.workingHours.replaceFirst(
                                        'Ежедневно ',
                                        '',
                                      ),
                                      subtitle: 'ежедневный режим работы',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(StarKidsSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: StarKidsColors.surfaceTertiary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: StarKidsColors.brandPrimary,
                  size: StarKidsIconSizes.md,
                ),
              ),
              const Spacer(),
              Text(title, style: textTheme.titleLarge),
              const SizedBox(height: StarKidsSpacing.xs),
              Text(subtitle, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustStat extends StatelessWidget {
  const _TrustStat({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.md),
      decoration: BoxDecoration(
        color: StarKidsColors.surfaceCanvas,
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleLarge),
          const SizedBox(height: StarKidsSpacing.xs),
          Text(subtitle, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
