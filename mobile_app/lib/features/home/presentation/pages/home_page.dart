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
import '../../../../core/design_system/widgets/star_kids_cosmic_canvas.dart';
import '../../../../core/design_system/widgets/star_kids_faq_card.dart';
import '../../../../core/design_system/widgets/star_kids_media_image.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_promo_card.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../birthdays/domain/birthday_package.dart';
import '../../../branches/domain/branch_option.dart';
import '../../../content/domain/public_content_block.dart';
import '../../../content/domain/public_faq_item.dart';
import '../../../news/presentation/controllers/news_feed_controller.dart';
import '../../../news/presentation/widgets/home_news_section.dart';
import '../../../promotions/domain/promotion_offer.dart';
import '../../../requests/domain/request_type.dart';
import '../../../requests/presentation/models/request_page_args.dart';
import '../../../tickets/presentation/sheets/ticket_purchase_flow_sheet.dart';
import '../../../tickets/presentation/sheets/tickets_entry_sheet.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.newsController,
  });

  final NewsFeedController? newsController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;
        final textTheme = Theme.of(context).textTheme;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          // Glass floating nav bar
          bottomNavigationBar: _FloatingNavBar(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              unawaited(_handleNavigationSelection(context, index));
            },
          ),
          body: StarKidsCosmicCanvas(
            child: SafeArea(
              bottom: false,
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
                          child: Row(
                            children: [
                              Expanded(
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
                                      color: isDark
                                          ? StarKidsDarkColors.glassSurface
                                          : StarKidsColors.glassSurface,
                                      borderRadius: BorderRadius.circular(
                                        StarKidsRadii.full,
                                      ),
                                      border: Border.all(
                                        color: isDark
                                            ? StarKidsDarkColors.glassStroke
                                            : StarKidsColors.glassStroke,
                                      ),
                                      boxShadow: isDark
                                          ? StarKidsShadows.depth1Dark
                                          : StarKidsShadows.depth1,
                                    ),
                                    child: Row(
                                      children: [
                                        ShaderMask(
                                          shaderCallback: (bounds) =>
                                              const LinearGradient(
                                            colors: [
                                              StarKidsColors.brandPrimary,
                                              Color(0xFFB044EB),
                                            ],
                                          ).createShader(bounds),
                                          child: const Icon(
                                            Icons.location_on_rounded,
                                            size: StarKidsIconSizes.sm,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(
                                          width: StarKidsSpacing.sm,
                                        ),
                                        Expanded(
                                          child: Text(
                                            branch.name,
                                            style: textTheme.labelLarge,
                                          ),
                                        ),
                                        Icon(
                                          Icons.expand_more_rounded,
                                          color: isDark
                                              ? StarKidsDarkColors
                                                  .textSecondary
                                              : StarKidsColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: StarKidsSpacing.md),
                              _HomeActionButton(
                                icon: Icons.notifications_none_rounded,
                                onTap: () => Navigator.of(context).pushNamed(
                                  AppRoutes.notifications,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: StarKidsSpacing.lg),
                        // Hero image card
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
                                    fallbackSource:
                                        'assets/images/home_hero.jpg',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          style:
                                              textTheme.labelMedium?.copyWith(
                                            color: StarKidsColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                          height: StarKidsSpacing.md),
                                      Text(
                                        'Яркий семейный отдых и дни рождения в Star Kids',
                                        style: textTheme.displayLarge?.copyWith(
                                          color: StarKidsColors.textInverse,
                                        ),
                                      ),
                                      const SizedBox(
                                          height: StarKidsSpacing.md),
                                      Text(
                                        'Выберите филиал, посмотрите пакеты и отправьте заявку без лишних шагов.',
                                        style: textTheme.bodyLarge?.copyWith(
                                          color: StarKidsColors.textInverse,
                                        ),
                                      ),
                                      const SizedBox(
                                          height: StarKidsSpacing.lg),
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
                        HomeNewsSection(newsController: newsController),
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
                        // Overflow fix: mainAxisExtent replaces childAspectRatio
                        GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: StarKidsSpacing.md,
                            crossAxisSpacing: StarKidsSpacing.md,
                            mainAxisExtent: 164,
                          ),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 6,
                          itemBuilder: (context, index) {
                            return _quickActionTiles(context)[index];
                          },
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
                                          initialPackage:
                                              content.featuredPackage,
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
                                    title:
                                        'Актуальные акции и поводы вернуться',
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
                                              badgeLabel:
                                                  entry.value.badgeLabel,
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
                                    ...content.contentBlocks
                                        .asMap()
                                        .entries
                                        .map(
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
                                    _TrustBlock(branch: homeBranch),
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
                        // Bottom padding for floating nav bar clearance
                        const SizedBox(height: 96),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _quickActionTiles(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dark mode uses nebula accent colors; light mode uses light pastels.
    final tileColors = isDark
        ? const [
            [Color(0x2A3B82F6), Color(0x1A10B981)],
            [Color(0x2AA855F7), Color(0x1A3B82F6)],
            [Color(0x2AFF6B6B), Color(0x1AA855F7)],
            [Color(0x1A3B82F6), Color(0x2AA855F7)],
            [Color(0x2AFBBF24), Color(0x1A10B981)],
            [Color(0x2AFF0F90), Color(0x1AA855F7)],
          ]
        : const [
            [StarKidsColors.cosmicSky, StarKidsColors.cosmicMint],
            [StarKidsColors.cosmicBlush, StarKidsColors.cosmicLavender],
            [StarKidsColors.cosmicPeach, StarKidsColors.cosmicBlush],
            [StarKidsColors.cosmicLavender, StarKidsColors.cosmicSky],
            [StarKidsColors.cosmicPeach, StarKidsColors.cosmicMint],
            [StarKidsColors.cosmicBlush, StarKidsColors.cosmicPeach],
          ];

    return [
      _QuickActionTile(
        icon: Icons.map_rounded,
        title: 'Филиал и маршрут',
        subtitle: 'Как доехать и что внутри',
        revealDelay: starKidsStaggerDelay(0, initialMs: 80),
        gradientColors: tileColors[0],
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.branchDetails),
      ),
      _QuickActionTile(
        icon: Icons.cake_rounded,
        title: 'Дни рождения',
        subtitle: 'Пакеты и быстрый запрос',
        revealDelay: starKidsStaggerDelay(1, initialMs: 80),
        gradientColors: tileColors[1],
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.birthdays),
      ),
      _QuickActionTile(
        icon: Icons.restaurant_menu_rounded,
        title: 'Меню',
        subtitle: 'Еда и напитки в филиале',
        revealDelay: starKidsStaggerDelay(2, initialMs: 80),
        gradientColors: tileColors[2],
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.menu),
      ),
      _QuickActionTile(
        icon: Icons.pin_drop_rounded,
        title: 'Контакты',
        subtitle: 'Звонок, WhatsApp, маршрут',
        revealDelay: starKidsStaggerDelay(3, initialMs: 80),
        gradientColors: tileColors[3],
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.contacts),
      ),
      _QuickActionTile(
        icon: Icons.local_offer_rounded,
        title: 'Акции',
        subtitle: 'Текущие предложения',
        revealDelay: starKidsStaggerDelay(4, initialMs: 80),
        gradientColors: tileColors[4],
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.promotions),
      ),
      _QuickActionTile(
        icon: Icons.chat_bubble_rounded,
        title: 'Запрос менеджеру',
        subtitle: 'Вопрос по филиалу',
        revealDelay: starKidsStaggerDelay(5, initialMs: 80),
        gradientColors: tileColors[5],
        onTap: () => Navigator.of(context).pushNamed(
          AppRoutes.requests,
          arguments: const RequestPageArgs(
            initialType: RequestType.contact,
          ),
        ),
      ),
    ];
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

/// Floating glass navigation bar that appears to float above the content.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        StarKidsSpacing.lg,
        StarKidsSpacing.sm,
        StarKidsSpacing.lg,
        StarKidsSpacing.md + bottomPadding,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(StarKidsRadii.full),
          boxShadow: isDark
              ? StarKidsShadows.navFloatDark
              : StarKidsShadows.navFloat,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(StarKidsRadii.full),
          child: Builder(
            builder: (ctx) {
              final l = AppL10n.of(ctx);

              final navBar = NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_rounded),
                    label: l.navHome,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.cake_rounded),
                    label: l.navBirthdays,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.local_offer_rounded),
                    label: l.navPromotions,
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.confirmation_num_rounded),
                    label: 'Билеты',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_rounded),
                    label: l.navProfile,
                  ),
                ],
              );

              return navBar;
            },
          ),
        ),
      ),
    );
  }
}

/// Glass matte quick-action tile with gradient icon and elastic press.
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    this.revealDelay = Duration.zero,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Duration revealDelay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StarKidsReveal(
      delay: revealDelay,
      child: StarKidsPressEffect(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.05),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.88),
                      Colors.white.withValues(alpha: 0.68),
                    ],
            ),
            borderRadius: BorderRadius.circular(StarKidsRadii.xl),
            border: Border.all(
              color: isDark
                  ? StarKidsDarkColors.glassStroke
                  : StarKidsColors.glassStroke,
              width: 1.0,
            ),
            boxShadow: isDark ? const [] : StarKidsShadows.cosmicCard,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(StarKidsRadii.xl),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                splashColor: gradientColors.first.withValues(alpha: 0.4),
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(StarKidsSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon container with gradient background
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(StarKidsRadii.md),
                          boxShadow: isDark ? const [] : StarKidsShadows.iconGlow,
                        ),
                        child: Icon(
                          icon,
                          color: isDark
                              ? StarKidsDarkColors.accentPink
                              : StarKidsColors.brandPrimary,
                          size: StarKidsIconSizes.md,
                        ),
                      ),
                      const SizedBox(height: StarKidsSpacing.md),
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
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(StarKidsRadii.full),
        onTap: onTap,
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isDark
                ? StarKidsDarkColors.glassSurface
                : StarKidsColors.glassSurface,
            borderRadius: BorderRadius.circular(StarKidsRadii.full),
            border: Border.all(
              color: isDark
                  ? StarKidsDarkColors.glassStroke
                  : StarKidsColors.glassStroke,
            ),
            boxShadow: isDark ? StarKidsShadows.depth1Dark : StarKidsShadows.depth1,
          ),
          child: Icon(
            icon,
            color: isDark
                ? StarKidsDarkColors.textPrimary
                : StarKidsColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TrustBlock extends StatelessWidget {
  const _TrustBlock({required this.branch});

  final BranchOption branch;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? StarKidsDarkColors.glassSurface : StarKidsColors.glassSurface,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(
          color: isDark ? StarKidsDarkColors.glassStroke : StarKidsColors.glassStroke,
        ),
        boxShadow: isDark ? const [] : StarKidsShadows.cosmicCard,
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
            children: branch.facilities
                .take(4)
                .map(
                  (facility) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StarKidsSpacing.md,
                      vertical: StarKidsSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [
                                Color(0x2AA855F7),
                                Color(0x1A3B82F6),
                              ],
                            )
                          : const LinearGradient(
                              colors: [
                                StarKidsColors.cosmicBlush,
                                StarKidsColors.cosmicLavender,
                              ],
                            ),
                      borderRadius: BorderRadius.circular(StarKidsRadii.full),
                      border: isDark
                          ? Border.all(color: StarKidsDarkColors.borderDefault)
                          : null,
                    ),
                    child: Text(
                      facility,
                      style: textTheme.labelMedium,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          Row(
            children: [
              const Expanded(
                child: _TrustStat(
                  title: '3000 кв.м',
                  subtitle: 'пространства',
                ),
              ),
              const SizedBox(width: StarKidsSpacing.md),
              Expanded(
                child: _TrustStat(
                  title: branch.workingHours.replaceFirst('Ежедневно ', ''),
                  subtitle: 'ежедневно',
                ),
              ),
            ],
          ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.md),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x1A3B82F6), Color(0x1AA855F7)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [StarKidsColors.cosmicLavender, StarKidsColors.cosmicSky],
              ),
        borderRadius: BorderRadius.circular(StarKidsRadii.lg),
        border: Border.all(
          color: isDark ? StarKidsDarkColors.borderDefault : StarKidsColors.glassStroke,
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? StarKidsDarkColors.glassSurface : StarKidsColors.glassSurface,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(
          color: isDark ? StarKidsDarkColors.glassStroke : StarKidsColors.glassStroke,
        ),
        boxShadow: isDark ? const [] : StarKidsShadows.cosmicCard,
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
