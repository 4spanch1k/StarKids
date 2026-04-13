import 'dart:async';

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
import '../../../../core/design_system/widgets/star_kids_content_block_card.dart';
import '../../../../core/design_system/widgets/star_kids_faq_card.dart';
import '../../../../core/design_system/widgets/star_kids_media_image.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_promo_card.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../birthdays/domain/birthday_package.dart';
import '../../../branches/domain/branch_option.dart';
import '../../../content/domain/public_content_block.dart';
import '../../../content/domain/public_faq_item.dart';
import '../../../promotions/domain/promotion_offer.dart';
import '../../../requests/domain/request_type.dart';
import '../../../requests/presentation/models/request_page_args.dart';
import '../../../tickets/presentation/sheets/ticket_purchase_flow_sheet.dart';
import '../../../tickets/presentation/sheets/tickets_entry_sheet.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;
        final textTheme = Theme.of(context).textTheme;
        final isCompactHomeLayout = MediaQuery.of(context).size.width < 430;

        return Scaffold(
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              unawaited(_handleNavigationSelection(context, index));
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
                icon: Icon(Icons.confirmation_num_rounded),
                label: 'Билеты',
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
                    delegate: SliverChildListDelegate([
                      StarKidsReveal(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            StarKidsRadii.full,
                          ),
                          onTap: () => Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.branchSelection),
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
                                color: StarKidsColors.borderDefault,
                              ),
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
                      ),
                      const SizedBox(height: StarKidsSpacing.lg),
                      StarKidsReveal(
                        delay: starKidsStaggerDelay(1),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            StarKidsRadii.hero,
                          ),
                          child: Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: StarKidsMediaImage(
                                  source: branch.heroImagePath,
                                  fallbackSource: 'assets/images/home_hero.jpg',
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
                                      onPressed: () => Navigator.of(
                                        context,
                                      ).pushNamed(AppRoutes.birthdays),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: StarKidsSpacing.x2l),
                      const StarKidsReveal(
                        delay: Duration(milliseconds: 80),
                        child: StarKidsSectionHeader(
                          title: 'Быстрые действия',
                          description:
                              'Самые частые сценарии для родителей собраны в один блок.',
                        ),
                      ),
                      const SizedBox(height: StarKidsSpacing.lg),
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: StarKidsSpacing.md,
                        crossAxisSpacing: StarKidsSpacing.md,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: isCompactHomeLayout ? 1.08 : 1.38,
                        children: [
                          _QuickActionTile(
                            icon: Icons.map_rounded,
                            title: 'Филиал и маршрут',
                            subtitle: 'Как доехать и что внутри',
                            revealDelay: starKidsStaggerDelay(0, initialMs: 80),
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.branchDetails),
                          ),
                          _QuickActionTile(
                            icon: Icons.cake_rounded,
                            title: 'Дни рождения',
                            subtitle: 'Пакеты и быстрый запрос',
                            revealDelay: starKidsStaggerDelay(1, initialMs: 80),
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.birthdays),
                          ),
                          _QuickActionTile(
                            icon: Icons.restaurant_menu_rounded,
                            title: 'Меню',
                            subtitle: 'Еда и напитки в филиале',
                            revealDelay: starKidsStaggerDelay(2, initialMs: 80),
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.menu),
                          ),
                          _QuickActionTile(
                            icon: Icons.pin_drop_rounded,
                            title: 'Контакты и маршрут',
                            subtitle: 'Звонок, WhatsApp и как доехать',
                            revealDelay: starKidsStaggerDelay(3, initialMs: 80),
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.contacts),
                          ),
                          _QuickActionTile(
                            icon: Icons.local_offer_rounded,
                            title: 'Акции',
                            subtitle: 'Текущие предложения и поводы вернуться',
                            revealDelay: starKidsStaggerDelay(4, initialMs: 80),
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.promotions),
                          ),
                          _QuickActionTile(
                            icon: Icons.chat_bubble_rounded,
                            title: 'Запрос менеджеру',
                            subtitle: 'Вопрос по филиалу и услугам',
                            revealDelay: starKidsStaggerDelay(5, initialMs: 80),
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.requests,
                              arguments: const RequestPageArgs(
                                initialType: RequestType.contact,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: StarKidsSpacing.x2l),
                      FutureBuilder<_HomeContentData>(
                        future: _loadHomeContent(branch.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const StarKidsContentSwitcher(
                              child: Padding(
                                key: ValueKey('home-content-loading'),
                                padding: EdgeInsets.symmetric(
                                  vertical: StarKidsSpacing.x2l,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            );
                          }

                          final content = snapshot.data ??
                              _HomeContentData(
                                branch: branch,
                                promotions: <PromotionOffer>[],
                                contentBlocks: <PublicContentBlock>[],
                                faqs: <PublicFaqItem>[],
                              );
                          final homeBranch = content.branch;

                          return StarKidsContentSwitcher(
                            child: Column(
                              key: ValueKey(
                                'home-content-${homeBranch.id}-${content.promotions.length}-${content.contentBlocks.length}-${content.faqs.length}',
                              ),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StarKidsSectionHeader(
                                  title: 'Главный пакет для праздника',
                                  description:
                                      'Готовое коммерческое предложение, которое проще всего открыть с главного экрана.',
                                  actionLabel: 'Все пакеты',
                                  onActionTap: () => Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.birthdays),
                                ),
                                const SizedBox(height: StarKidsSpacing.lg),
                                if (content.featuredPackage != null)
                                  StarKidsBirthdayPackageCard(
                                    revealDelay: starKidsStaggerDelay(0),
                                    title: content.featuredPackage!.name,
                                    priceLabel:
                                        content.featuredPackage!.priceLabel,
                                    guestLabel:
                                        content.featuredPackage!.guestLabel,
                                    description:
                                        content.featuredPackage!.description,
                                    highlights:
                                        content.featuredPackage!.highlights,
                                    imagePath:
                                        content.featuredPackage!.imagePath,
                                    isFeatured:
                                        content.featuredPackage!.isFeatured,
                                    onActionTap: () =>
                                        Navigator.of(context).pushNamed(
                                      AppRoutes.requests,
                                      arguments: RequestPageArgs(
                                        initialType:
                                            RequestType.birthdayRequest,
                                        initialPackageId:
                                            content.featuredPackage!.id,
                                        initialPackage: content.featuredPackage,
                                      ),
                                    ),
                                  )
                                else
                                  const _HomeStateCard(
                                    title: 'Пакеты скоро появятся',
                                    description:
                                        'Для выбранного филиала пока нет опубликованных пакетов. Можно оставить общую заявку, и менеджер поможет подобрать формат.',
                                  ),
                                const SizedBox(height: StarKidsSpacing.x2l),
                                const StarKidsSectionHeader(
                                  title: 'Актуальные акции и поводы вернуться',
                                  description:
                                      'Живые предложения из админки должны быть заметны, но не превращаться в визуальный шум.',
                                ),
                                const SizedBox(height: StarKidsSpacing.lg),
                                if (content.promotions.isNotEmpty)
                                  ...content.promotions
                                      .take(2)
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: StarKidsSpacing.md,
                                          ),
                                          child: StarKidsPromoCard(
                                            revealDelay: starKidsStaggerDelay(
                                              entry.key,
                                            ),
                                            title: entry.value.title,
                                            description:
                                                entry.value.description,
                                            imagePath: entry.value.imagePath,
                                            badgeLabel: entry.value.badgeLabel,
                                            onTap: () => Navigator.of(
                                              context,
                                            ).pushNamed(AppRoutes.promotions),
                                          ),
                                        ),
                                      )
                                else
                                  const _HomeStateCard(
                                    title: 'Акции скоро появятся',
                                    description:
                                        'По выбранному филиалу пока нет активных предложений. Остальные экраны приложения продолжают работать в обычном режиме.',
                                  ),
                                const SizedBox(height: StarKidsSpacing.x2l),
                                if (content.contentBlocks.isNotEmpty) ...[
                                  const StarKidsSectionHeader(
                                    title: 'Что важно перед визитом',
                                    description:
                                        'Контентные блоки из админки помогают обновлять ключевые сообщения без ручной правки приложения.',
                                  ),
                                  const SizedBox(height: StarKidsSpacing.lg),
                                  ...content.contentBlocks.asMap().entries.map(
                                        (entry) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: StarKidsSpacing.md,
                                          ),
                                          child: StarKidsContentBlockCard(
                                            revealDelay: starKidsStaggerDelay(
                                              entry.key,
                                            ),
                                            title: entry.value.title,
                                            body: entry.value.body,
                                            label: entry.value.ctaLabel,
                                          ),
                                        ),
                                      ),
                                ] else ...[
                                  const StarKidsSectionHeader(
                                    title: 'Почему сюда удобно возвращаться',
                                    description:
                                        'Четкий trust-block для повторного визита и быстрой заявки.',
                                  ),
                                  const SizedBox(height: StarKidsSpacing.lg),
                                  Container(
                                    padding: const EdgeInsets.all(
                                      StarKidsSpacing.lg,
                                    ),
                                    decoration: BoxDecoration(
                                      color: StarKidsColors.surfacePrimary,
                                      borderRadius: BorderRadius.circular(
                                        StarKidsRadii.xl,
                                      ),
                                      border: Border.all(
                                        color: StarKidsColors.borderDefault,
                                      ),
                                      boxShadow: StarKidsShadows.depth1,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Star Kids помогает быстро решить семейный досуг: выбрать филиал, понять условия и сразу перейти к празднику или заявке.',
                                          style: textTheme.bodyLarge,
                                        ),
                                        const SizedBox(
                                          height: StarKidsSpacing.lg,
                                        ),
                                        Wrap(
                                          spacing: StarKidsSpacing.sm,
                                          runSpacing: StarKidsSpacing.sm,
                                          children: homeBranch.facilities
                                              .take(4)
                                              .map(
                                                (facility) => Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal:
                                                        StarKidsSpacing.md,
                                                    vertical:
                                                        StarKidsSpacing.xs,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: StarKidsColors
                                                        .surfaceSecondary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      StarKidsRadii.full,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    facility,
                                                    style: textTheme.labelMedium
                                                        ?.copyWith(
                                                      color: StarKidsColors
                                                          .textPrimary,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                        const SizedBox(
                                          height: StarKidsSpacing.lg,
                                        ),
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: _TrustStat(
                                                title: '3000 кв.м',
                                                subtitle:
                                                    'пространства для активности',
                                              ),
                                            ),
                                            const SizedBox(
                                              width: StarKidsSpacing.md,
                                            ),
                                            Expanded(
                                              child: _TrustStat(
                                                title: homeBranch.workingHours
                                                    .replaceFirst(
                                                  'Ежедневно ',
                                                  '',
                                                ),
                                                subtitle:
                                                    'ежедневный режим работы',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (content.faqs.isNotEmpty) ...[
                                  const SizedBox(height: StarKidsSpacing.x2l),
                                  const StarKidsSectionHeader(
                                    title: 'Частые вопросы',
                                    description:
                                        'Ответы из live-контента помогают снять базовые вопросы до заявки или звонка.',
                                  ),
                                  const SizedBox(height: StarKidsSpacing.lg),
                                  ...content.faqs
                                      .take(3)
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: StarKidsSpacing.md,
                                          ),
                                          child: StarKidsFaqCard(
                                            revealDelay: starKidsStaggerDelay(
                                              entry.key,
                                            ),
                                            question: entry.value.question,
                                            answer: entry.value.answer,
                                          ),
                                        ),
                                      ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_HomeContentData> _loadHomeContent(String branchId) async {
    final branch =
        await ServiceRegistry.branchRepository.getBranch(branchId).catchError(
              (_) => ServiceRegistry.selectedBranchController.selectedBranch,
            );
    ServiceRegistry.selectedBranchController.syncSelectedBranch(branch);
    final packages = await ServiceRegistry.birthdayPackageRepository
        .listPackages(branchId: branchId)
        .catchError((_) => const <BirthdayPackage>[]);
    final promotions = await ServiceRegistry.promotionRepository
        .listPromotions(branchId)
        .catchError((_) => const <PromotionOffer>[]);
    final contentBlocks = await ServiceRegistry.publicContentRepository
        .listContentBlocks(surface: 'home')
        .catchError((_) => const <PublicContentBlock>[]);
    final faqs = await ServiceRegistry.publicContentRepository
        .listFaqs()
        .catchError((_) => const <PublicFaqItem>[]);

    BirthdayPackage? featuredPackage;
    for (final item in packages) {
      if (item.isFeatured) {
        featuredPackage = item;
        break;
      }
    }
    featuredPackage ??= packages.isEmpty ? null : packages.first;

    return _HomeContentData(
      branch: branch,
      featuredPackage: featuredPackage,
      promotions: promotions,
      contentBlocks: contentBlocks,
      faqs: faqs,
    );
  }
}

Future<void> _handleNavigationSelection(BuildContext context, int index) async {
  switch (index) {
    case 1:
      Navigator.of(context).pushNamed(AppRoutes.birthdays);
      return;
    case 2:
      Navigator.of(context).pushNamed(AppRoutes.promotions);
      return;
    case 3:
      final action = await showTicketsEntrySheet(context);
      if (!context.mounted || action == null) {
        return;
      }

      switch (action) {
        case TicketsEntryAction.myTickets:
          await showMyTicketsSheet(context);
          return;
        case TicketsEntryAction.buyTicket:
          await showTicketPurchaseFlowSheet(context);
          return;
      }
    case 4:
      Navigator.of(context).pushNamed(AppRoutes.profile);
      return;
    case 0:
    default:
      return;
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.revealDelay = Duration.zero,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Duration revealDelay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return StarKidsReveal(
      delay: revealDelay,
      child: Card(
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
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: StarKidsSpacing.xs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: StarKidsColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustStat extends StatelessWidget {
  const _TrustStat({required this.title, required this.subtitle});

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

class _HomeStateCard extends StatelessWidget {
  const _HomeStateCard({required this.title, required this.description});

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

class _HomeContentData {
  const _HomeContentData({
    required this.branch,
    this.featuredPackage,
    required this.promotions,
    required this.contentBlocks,
    required this.faqs,
  });

  final BranchOption branch;
  final BirthdayPackage? featuredPackage;
  final List<PromotionOffer> promotions;
  final List<PublicContentBlock> contentBlocks;
  final List<PublicFaqItem> faqs;
}
