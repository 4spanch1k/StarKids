import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_bottom_nav.dart';
import '../../../../core/design_system/widgets/glass_container.dart';
import '../../../../core/design_system/widgets/glass_drawer.dart';
import '../../../../core/design_system/widgets/sk_button.dart';
import '../../../../core/design_system/widgets/sk_hero.dart';
import '../../../../core/design_system/widgets/star_kids_birthday_package_card.dart';
import '../../../../core/design_system/widgets/star_kids_content_block_card.dart';
import '../../../../core/design_system/widgets/star_kids_cosmic_canvas.dart';
import '../../../../core/design_system/widgets/star_kids_faq_card.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_promo_card.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../../core/design_system/widgets/stable_future_builder.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.newsController,
  });

  final NewsFeedController? newsController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final NewsFeedController _newsController;
  late final bool _ownsNewsController;

  @override
  void initState() {
    super.initState();
    _ownsNewsController = widget.newsController == null;
    _newsController = widget.newsController ??
        NewsFeedController(
          repository: ServiceRegistry.newsRepository,
          feedKind: NewsFeedKind.promotions,
          pageSize: 6,
        );
  }

  @override
  void dispose() {
    if (_ownsNewsController) {
      _newsController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;

        return Scaffold(
          key: _scaffoldKey,
          extendBody: true,
          appBar: GlassAppBar(
            leading: GlassIconButton(
              icon: Icons.menu_rounded,
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: _BranchPill(branch: branch),
            trailing: GlassIconButton(
              icon: Icons.notifications_none_rounded,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.notifications),
            ),
          ),
          drawer: const GlassDrawer(child: _AppDrawer()),
          bottomNavigationBar: _GlassNav(
            onChanged: (id) => unawaited(_handleNavChange(context, id)),
          ),
          body: StarKidsCosmicCanvas(
            child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _newsController.forceRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        SKSpacing.x5,
                        SKSpacing.x4,
                        SKSpacing.x5,
                        96.0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          StarKidsReveal(
                            delay: starKidsStaggerDelay(1),
                            child: SkHero(
                              imageUrl: 'assets/images/home_hero.jpg',
                              fallbackImagePath: 'assets/images/home_hero.jpg',
                              chip: '✦ Любят дети · доверяют родители',
                              title: 'Семейный отдых\nи яркие дни рождения.',
                              italicText: 'яркие',
                              meta: '3000 м² · 11:00 — 23:00',
                              action: SkButton(
                                label: 'Организовать день рождения',
                                style: SkButtonStyle.accent,
                                block: true,
                                icon: const Icon(Icons.arrow_forward_rounded),
                                iconRight: true,
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.birthdays),
                              ),
                            ),
                          ),
                          const SizedBox(height: SKSpacing.x6),
                          HomeNewsSection(newsController: _newsController),
                          const SizedBox(height: SKSpacing.x6),
                          const StarKidsReveal(
                            delay: Duration(milliseconds: 80),
                            child: StarKidsSectionHeader(
                              title: 'Быстрые действия',
                            ),
                          ),
                          const SizedBox(height: SKSpacing.x4),
                          GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: SKSpacing.x3,
                              crossAxisSpacing: SKSpacing.x3,
                              mainAxisExtent:
                                  MediaQuery.sizeOf(context).width < 380
                                      ? 164
                                      : 176,
                            ),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 6,
                            itemBuilder: (context, index) {
                              return _quickActionTiles(context)[index];
                            },
                          ),
                          const SizedBox(height: SKSpacing.x6),
                          StableFutureBuilder<_HomeContentData>(
                            cacheKey: branch.id,
                            futureFactory: () => _loadHomeContent(branch.id),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !snapshot.hasData) {
                                return const StarKidsContentSwitcher(
                                  child: Padding(
                                    key: ValueKey('home-content-loading'),
                                    padding: EdgeInsets.symmetric(
                                      vertical: SKSpacing.x6,
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
                                      title: 'Лучший пакет для дня рождения',
                                      actionLabel: 'Все пакеты',
                                      onActionTap: () => Navigator.of(
                                        context,
                                      ).pushNamed(AppRoutes.birthdays),
                                    ),
                                    const SizedBox(height: SKSpacing.x4),
                                    if (content.featuredPackage != null)
                                      StarKidsBirthdayPackageCard(
                                        revealDelay: starKidsStaggerDelay(0),
                                        title: content.featuredPackage!.name,
                                        priceLabel:
                                            content.featuredPackage!.priceLabel,
                                        guestLabel:
                                            content.featuredPackage!.guestLabel,
                                        description: content
                                            .featuredPackage!.description,
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
                                    const SizedBox(height: SKSpacing.x6),
                                    const StarKidsSectionHeader(
                                      title: 'Актуальные акции',
                                    ),
                                    const SizedBox(height: SKSpacing.x4),
                                    if (content.promotions.isNotEmpty)
                                      ...content.promotions
                                          .take(2)
                                          .toList()
                                          .asMap()
                                          .entries
                                          .map(
                                            (entry) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: SKSpacing.x3,
                                              ),
                                              child: StarKidsPromoCard(
                                                revealDelay:
                                                    starKidsStaggerDelay(
                                                  entry.key,
                                                ),
                                                title: entry.value.title,
                                                description:
                                                    entry.value.description,
                                                imagePath:
                                                    entry.value.imagePath,
                                                badgeLabel:
                                                    entry.value.badgeLabel,
                                                onTap: () => Navigator.of(
                                                  context,
                                                ).pushNamed(
                                                    AppRoutes.promotions),
                                              ),
                                            ),
                                          )
                                    else
                                      const _HomeStateCard(
                                        title: 'Акции скоро появятся',
                                        description:
                                            'По выбранному филиалу пока нет активных предложений. Остальные экраны приложения продолжают работать в обычном режиме.',
                                      ),
                                    const SizedBox(height: SKSpacing.x6),
                                    if (content.contentBlocks.isNotEmpty) ...[
                                      const StarKidsSectionHeader(
                                        title: 'Что важно перед визитом',
                                      ),
                                      const SizedBox(height: SKSpacing.x4),
                                      ...content.contentBlocks
                                          .asMap()
                                          .entries
                                          .map(
                                            (entry) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: SKSpacing.x3,
                                              ),
                                              child: StarKidsContentBlockCard(
                                                revealDelay:
                                                    starKidsStaggerDelay(
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
                                        title: 'Почему Star Kids',
                                        description:
                                            'Пространство, которое дети любят, а родители ценят за удобство.',
                                      ),
                                      const SizedBox(height: SKSpacing.x4),
                                      _TrustBlock(branch: homeBranch),
                                    ],
                                    if (content.faqs.isNotEmpty) ...[
                                      const SizedBox(height: SKSpacing.x6),
                                      const StarKidsSectionHeader(
                                        title: 'Частые вопросы',
                                      ),
                                      const SizedBox(height: SKSpacing.x4),
                                      ...content.faqs
                                          .take(3)
                                          .toList()
                                          .asMap()
                                          .entries
                                          .map(
                                            (entry) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: SKSpacing.x3,
                                              ),
                                              child: StarKidsFaqCard(
                                                revealDelay:
                                                    starKidsStaggerDelay(
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
                          const SizedBox(height: 96),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _quickActionTiles(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dark mode: semi-transparent tints. Light mode: warm pastel pairs.
    final tileColors = isDark
        ? const [
            [Color(0x2A3B82F6), Color(0x1A10B981)],
            [Color(0x24E5D4F2), Color(0x18C7DDEF)],
            [Color(0x24FF5A5F), Color(0x18E5D4F2)],
            [Color(0x18C7DDEF), Color(0x24E5D4F2)],
            [Color(0x2AFBBF24), Color(0x1A10B981)],
            [Color(0x24FF5A5F), Color(0x18E5D4F2)],
          ]
        : const [
            [Color(0xFFC7DDEF), Color(0xFFB6E3C8)],
            [Color(0xFFFFE7E5), Color(0xFFE5D4F2)],
            [Color(0xFFB6E3C8), Color(0xFFC7DDEF)],
            [Color(0xFFE5D4F2), Color(0xFFC7DDEF)],
            [Color(0xFFFFF0CC), Color(0xFFB6E3C8)],
            [Color(0xFFFFE7E5), Color(0xFFB6E3C8)],
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
    final branchFuture =
        ServiceRegistry.branchRepository.getBranch(branchId).catchError(
              (_) => ServiceRegistry.selectedBranchController.selectedBranch,
            );
    final packagesFuture = ServiceRegistry.birthdayPackageRepository
        .listPackages(branchId: branchId)
        .catchError((_) => const <BirthdayPackage>[]);
    final promotionsFuture = ServiceRegistry.promotionRepository
        .listPromotions(branchId)
        .catchError((_) => const <PromotionOffer>[]);
    final contentBlocksFuture = ServiceRegistry.publicContentRepository
        .listContentBlocks(surface: 'home')
        .catchError((_) => const <PublicContentBlock>[]);
    final faqsFuture = ServiceRegistry.publicContentRepository
        .listFaqs()
        .catchError((_) => const <PublicFaqItem>[]);

    final branch = await branchFuture;
    final packages = await packagesFuture;
    final promotions = await promotionsFuture;
    final contentBlocks = await contentBlocksFuture;
    final faqs = await faqsFuture;
    ServiceRegistry.selectedBranchController.syncSelectedBranch(branch);

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

Future<void> _handleNavChange(BuildContext context, String id) async {
  switch (id) {
    case 'birthdays':
      Navigator.of(context).pushNamed(AppRoutes.birthdays);
    case 'promotions':
      Navigator.of(context).pushNamed(AppRoutes.promotions);
    case 'tickets':
      final action = await showTicketsEntrySheet(context);
      if (!context.mounted || action == null) return;
      switch (action) {
        case TicketsEntryAction.myTickets:
          await showMyTicketsSheet(context);
        case TicketsEntryAction.buyTicket:
          await showTicketPurchaseFlowSheet(context);
      }
    case 'profile':
      Navigator.of(context).pushNamed(AppRoutes.profile);
  }
}

class _GlassNav extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _GlassNav({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return GlassBottomNav(
      value: 'home',
      onChanged: onChanged,
      items: [
        GlassNavItem(id: 'home', icon: Icons.home_outlined, label: l.navHome),
        GlassNavItem(
            id: 'birthdays', icon: Icons.cake_outlined, label: l.navBirthdays),
        GlassNavItem(
            id: 'promotions',
            icon: Icons.local_offer_outlined,
            label: l.navPromotions),
        const GlassNavItem(
            id: 'tickets',
            icon: Icons.confirmation_num_outlined,
            label: 'Билеты'),
        GlassNavItem(
            id: 'profile', icon: Icons.person_outline, label: l.navProfile),
      ],
    );
  }
}

class _BranchPill extends StatelessWidget {
  final BranchOption branch;
  const _BranchPill({required this.branch});

  @override
  Widget build(BuildContext context) {
    return GlassPill(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: SKSpacing.x4),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.branchSelection),
      child: _BranchPillContent(branch: branch),
    );
  }
}

class _BranchPillContent extends StatelessWidget {
  final BranchOption branch;
  const _BranchPillContent({required this.branch});

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on_rounded, size: 14, color: c.cta),
        const SizedBox(width: SKSpacing.x2),
        Flexible(
          child: Text(
            branch.name,
            overflow: TextOverflow.ellipsis,
            style: SKTextStyles.small.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: SKSpacing.x1),
        Icon(Icons.expand_more_rounded, size: 14, color: c.textTertiary),
      ],
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SKSpacing.x6,
            SKSpacing.x6,
            SKSpacing.x6,
            SKSpacing.x4,
          ),
          child: Text(
            'Star Kids',
            style: SKTextStyles.h1.copyWith(color: c.textPrimary),
          ),
        ),
        Divider(color: c.hairline, height: 1, thickness: 0.5),
        const SizedBox(height: SKSpacing.x2),
        GlassDrawerRow(
          icon: Icons.person_outline_rounded,
          label: 'Профиль',
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).pushNamed(AppRoutes.profile);
          },
        ),
        GlassDrawerRow(
          icon: Icons.history_rounded,
          label: 'История заявок',
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).pushNamed(AppRoutes.myRequests);
          },
        ),
        GlassDrawerRow(
          icon: Icons.local_offer_outlined,
          label: 'Акции',
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).pushNamed(AppRoutes.promotions);
          },
        ),
        GlassDrawerRow(
          icon: Icons.call_outlined,
          label: 'Контакты',
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).pushNamed(AppRoutes.contacts);
          },
        ),
        GlassDrawerRow(
          icon: Icons.notifications_none_rounded,
          label: 'Уведомления',
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).pushNamed(AppRoutes.notifications);
          },
        ),
      ],
    );
  }
}

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
    final c = SKTheme.of(context).colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 380;

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
            borderRadius: BorderRadius.circular(SKRadius.xl),
            border: Border.all(color: c.glassBorder, width: 1.0),
            boxShadow: isDark ? const [] : SKShadows.sm,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SKRadius.xl),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                splashColor: gradientColors.first.withValues(alpha: 0.4),
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(SKSpacing.x3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: compact ? 38 : 42,
                        height: compact ? 38 : 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(SKRadius.md),
                        ),
                        child: Icon(
                          icon,
                          color: c.accent,
                          size: compact ? 21 : 24,
                        ),
                      ),
                      SizedBox(
                        height: compact ? SKSpacing.x2 : SKSpacing.x3,
                      ),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: compact
                            ? textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              )
                            : textTheme.titleMedium,
                      ),
                      const SizedBox(height: SKSpacing.x1),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: compact
                            ? textTheme.bodySmall?.copyWith(fontSize: 12)
                            : textTheme.bodySmall,
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

class _TrustBlock extends StatelessWidget {
  const _TrustBlock({required this.branch});

  final BranchOption branch;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.all(SKSpacing.x4),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.xl),
        border: Border.all(color: c.hairline, width: 0.5),
        boxShadow: SKShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Семейный центр для детского досуга, дней рождений и незабываемых праздников в Шымкенте.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: SKSpacing.x4),
          Wrap(
            spacing: SKSpacing.x2,
            runSpacing: SKSpacing.x2,
            children: branch.facilities
                .take(4)
                .map(
                  (facility) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SKSpacing.x3,
                      vertical: SKSpacing.x1,
                    ),
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(SKRadius.pill),
                      border: Border.all(
                        color: c.hairline,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      facility,
                      style: textTheme.labelMedium,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: SKSpacing.x4),
          const Row(
            children: [
              Expanded(
                child: _TrustStat(
                  title: '3 000',
                  subtitle: 'м² пространства',
                ),
              ),
              SizedBox(width: SKSpacing.x2),
              Expanded(
                child: _TrustStat(
                  title: '12+',
                  subtitle: 'лет работы',
                ),
              ),
              SizedBox(width: SKSpacing.x2),
              Expanded(
                child: _TrustStat(
                  title: '4.9',
                  subtitle: 'рейтинг',
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
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.all(SKSpacing.x3),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.lg),
        border: Border.all(color: c.hairline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 24,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.48,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: SKSpacing.x1),
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
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.all(SKSpacing.x4),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.xl),
        border: Border.all(color: c.hairline, width: 0.5),
        boxShadow: SKShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SKSpacing.x2),
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
