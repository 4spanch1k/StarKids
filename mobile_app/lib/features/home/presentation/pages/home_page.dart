import 'dart:async';

// Legacy decorative widgets remain available to non-Home surfaces during the
// staged redesign; Home no longer renders them as primary content.
// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/widgets/star_kids_root_navigation.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_container.dart';
import '../../../../core/design_system/widgets/glass_drawer.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/star_kids_cosmic_canvas.dart';
import '../../../../core/design_system/widgets/star_kids_birthday_package_card.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../../core/design_system/widgets/stable_future_builder.dart';
import '../../../birthdays/domain/birthday_package.dart';
import '../../../branches/domain/branch_option.dart';
import '../../../children/domain/child.dart';
import '../../../children/presentation/controllers/children_controller.dart';
import '../../../content/domain/public_content_block.dart';
import '../../../content/domain/public_faq_item.dart';
import '../../../news/presentation/controllers/news_feed_controller.dart';
import '../../../news/presentation/widgets/home_news_section.dart';
import '../../../promotions/domain/promotion_offer.dart';
import '../../../tickets/presentation/sheets/ticket_purchase_flow_sheet.dart';
import '../../../tickets/data/api_issued_ticket_repository.dart';
import '../../../tickets/domain/issued_ticket.dart';
import '../../../tickets/domain/issued_ticket_repository.dart';
import '../../../tickets/presentation/pages/ticket_detail_page.dart';
import '../models/home_primary_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.newsController,
    this.issuedTicketRepository,
    this.childrenController,
    this.nowProvider,
  });

  final NewsFeedController? newsController;
  final IssuedTicketRepository? issuedTicketRepository;
  final ChildrenController? childrenController;
  final DateTime Function()? nowProvider;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final NewsFeedController _newsController;
  late final bool _ownsNewsController;
  late final IssuedTicketRepository _issuedTicketRepository;
  late final ChildrenController _childrenController;
  late final DateTime Function() _nowProvider;
  bool _isOpeningDestination = false;
  List<IssuedTicket> _issuedTickets = const [];
  bool _ticketsLoading = true;
  String? _ticketsError;
  int _secondaryRefreshVersion = 0;

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
    _issuedTicketRepository =
        widget.issuedTicketRepository ?? ServiceRegistry.issuedTicketRepository;
    _childrenController =
        widget.childrenController ?? ServiceRegistry.childrenController;
    _nowProvider = widget.nowProvider ?? DateTime.now;
    unawaited(_loadIssuedTickets());
    unawaited(_childrenController.load());
  }

  Future<void> _loadIssuedTickets() async {
    if (mounted) {
      setState(() {
        _ticketsLoading = true;
        _ticketsError = null;
      });
    }
    try {
      final tickets = List<IssuedTicket>.of(
        await _issuedTicketRepository.listIssuedTickets(),
      )..sort(_compareIssuedTickets);
      if (!mounted) return;
      setState(() {
        _issuedTickets = tickets;
        _ticketsLoading = false;
      });
    } on IssuedTicketApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _ticketsLoading = false;
        _ticketsError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ticketsLoading = false;
        _ticketsError = 'Не удалось загрузить билеты. Попробуйте еще раз.';
      });
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait<void>([
      _loadIssuedTickets(),
      _childrenController.load(),
      _newsController.forceRefresh(),
    ]);
    if (!mounted) return;
    setState(() => _secondaryRefreshVersion++);
  }

  @override
  void dispose() {
    if (_ownsNewsController) {
      _newsController.dispose();
    }
    super.dispose();
  }

  Future<void> _openNested(String route, {Object? arguments}) async {
    if (_isOpeningDestination) return;
    _isOpeningDestination = true;
    try {
      await Navigator.of(context).pushNamed(route, arguments: arguments);
    } finally {
      _isOpeningDestination = false;
    }
  }

  Future<void> _openTicketPurchase() async {
    if (_isOpeningDestination) return;
    _isOpeningDestination = true;
    try {
      final completed = await showTicketPurchaseFlowSheet(context);
      if (completed && mounted) {
        await Navigator.of(context).pushReplacementNamed(AppRoutes.tickets);
      }
    } finally {
      _isOpeningDestination = false;
    }
  }

  void _openRoot(String route) {
    if (_isOpeningDestination) return;
    _isOpeningDestination = true;
    Navigator.of(context).pushReplacementNamed(route);
  }

  Future<void> _openTicket(IssuedTicket ticket) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TicketDetailPage(
          ticketId: ticket.ticketId,
          initialTicket: ticket,
          repository: _issuedTicketRepository,
        ),
      ),
    );
    if (mounted) await _loadIssuedTickets();
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
          bottomNavigationBar: const StarKidsRootNavigation(current: 'home'),
          body: StarKidsCosmicCanvas(
            child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _refreshHome,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        SKSpacing.x5,
                        SKSpacing.x5,
                        SKSpacing.x5,
                        112.0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildPrimarySection(context),
                          const SizedBox(height: SKSpacing.x5),
                          _buildChildrenSection(context),
                          const SizedBox(height: SKSpacing.x4),
                          _buildSecondaryBirthdaySection(context),
                          const SizedBox(height: SKSpacing.x5),
                          _HomeQuickActions(
                            onBranchTap: () =>
                                _openNested(AppRoutes.branchDetails),
                            onBirthdayTap: () => _openRoot(AppRoutes.birthdays),
                            onMenuTap: () => _openNested(AppRoutes.menu),
                            onContactsTap: () =>
                                _openNested(AppRoutes.contacts),
                          ),
                          const SizedBox(height: SKSpacing.x5),
                          StableFutureBuilder<_HomeContentData>(
                            cacheKey: '${branch.id}-$_secondaryRefreshVersion',
                            futureFactory: () => _loadHomeContent(branch.id),
                            builder: (context, snapshot) {
                              final content = snapshot.data;
                              if (content == null) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (content.featuredPackage != null) ...[
                                    _HomeFeaturedPackage(
                                      package: content.featuredPackage!,
                                      onOpen: () =>
                                          _openRoot(AppRoutes.birthdays),
                                    ),
                                    if (content.promotions.isNotEmpty)
                                      const SizedBox(height: SKSpacing.x5),
                                  ],
                                  if (content.promotions.isNotEmpty)
                                    _HomePromotions(
                                      promotions: content.promotions,
                                    ),
                                ],
                              );
                            },
                          ),
                          HomeNewsSection(newsController: _newsController),
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

  Widget _buildPrimarySection(BuildContext context) {
    return AnimatedBuilder(
      animation: _childrenController,
      builder: (context, _) {
        final primary = resolveHomePrimaryState(
          tickets: _issuedTickets,
          children: _childrenController.children,
          now: _nowProvider(),
        );
        final hasUpcomingTicket = _issuedTickets.any(
          (ticket) => isUpcomingIssuedTicket(
            ticket,
            homeDateOnly(_nowProvider()),
          ),
        );
        if (_ticketsLoading && _issuedTickets.isEmpty) {
          return _buildTicketsSection(context);
        }
        if (_ticketsError != null && !hasUpcomingTicket) {
          return _buildTicketsSection(context);
        }
        switch (primary.state) {
          case HomePrimaryState.activeTicket:
            return _buildTicketsSection(context);
          case HomePrimaryState.birthday:
            return _BirthdayHero(
              key: const ValueKey('home-primary-birthday'),
              child: primary.child!,
              nextBirthday: primary.nextBirthday!,
              birthdayAge: primary.birthdayAge!,
              now: _nowProvider(),
              onOpen: () => _openRoot(AppRoutes.birthdays),
            );
          case HomePrimaryState.returningFamily:
            // Visit history is not available yet, so never invent a count.
            return _NewFamilyHero(
              key: const ValueKey('home-primary-returning-family'),
              returning: true,
              branchName:
                  ServiceRegistry.selectedBranchController.selectedBranch.name,
              onBuy: _openTicketPurchase,
            );
          case HomePrimaryState.newFamily:
            return KeyedSubtree(
              key: const ValueKey('home-primary-new-family'),
              child: _NewFamilyHero(
                key: const ValueKey('home-no-tickets'),
                branchName: ServiceRegistry
                    .selectedBranchController.selectedBranch.name,
                onBuy: _openTicketPurchase,
              ),
            );
        }
      },
    );
  }

  Widget _buildTicketsSection(BuildContext context) {
    final today = homeDateOnly(_nowProvider());
    final upcoming = _issuedTickets
        .where((ticket) => isUpcomingIssuedTicket(ticket, today))
        .toList();
    if (_ticketsLoading && _issuedTickets.isEmpty) {
      return const _HomeStateCard(
        key: ValueKey('home-tickets-loading'),
        icon: Icons.confirmation_num_outlined,
        title: 'Проверяем ваши билеты',
        description: 'Это займет несколько секунд.',
        showProgress: true,
      );
    }
    if (_ticketsError != null && upcoming.isEmpty) {
      return _HomeStateCard(
        key: const ValueKey('home-tickets-error'),
        icon: Icons.cloud_off_rounded,
        title: 'Билеты пока недоступны',
        description: _ticketsError!,
        action: SecondaryButton(
          label: 'Повторить',
          onPressed: _loadIssuedTickets,
        ),
        secondaryAction: PrimaryButton(
          label: 'Купить билет',
          icon: Icons.arrow_forward_rounded,
          onPressed: _openTicketPurchase,
        ),
      );
    }
    if (upcoming.isEmpty) {
      return _HomeStateCard(
        key: const ValueKey('home-no-tickets'),
        icon: Icons.local_activity_outlined,
        title: 'Планируете посещение?',
        description: 'Купите билет заранее — он появится здесь после оплаты.',
        action: PrimaryButton(
          label: 'Купить билет',
          icon: Icons.arrow_forward_rounded,
          onPressed: _openTicketPurchase,
        ),
      );
    }
    final ticket = upcoming.first;
    final groupedCount = upcoming.where((item) {
      return item.branchId == ticket.branchId &&
          item.visitDate?.year == ticket.visitDate?.year &&
          item.visitDate?.month == ticket.visitDate?.month &&
          item.visitDate?.day == ticket.visitDate?.day;
    }).length;
    return Column(
      key: const ValueKey('home-upcoming-ticket'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StarKidsSectionHeader(title: 'Ближайшее посещение'),
        const SizedBox(height: SKSpacing.x3),
        _HomeTicketCard(
          ticket: ticket,
          groupedCount: groupedCount,
          onOpen: () => _openTicket(ticket),
          onAllTickets: () => _openRoot(AppRoutes.tickets),
        ),
        const SizedBox(height: SKSpacing.x3),
        SecondaryButton(
          label: 'Купить ещё билет',
          icon: Icons.add_rounded,
          onPressed: _openTicketPurchase,
        ),
      ],
    );
  }

  Widget _buildChildrenSection(BuildContext context) {
    return AnimatedBuilder(
      animation: _childrenController,
      builder: (context, _) {
        final children = _childrenController.children;
        if (_childrenController.status == ChildrenStatus.loading &&
            children.isEmpty) {
          return const _HomeStateCard(
            key: ValueKey('home-children-loading'),
            icon: Icons.child_care_rounded,
            title: 'Загружаем детей',
            description: 'Подбираем данные вашей семьи.',
            showProgress: true,
            compact: true,
          );
        }
        if (_childrenController.status == ChildrenStatus.error) {
          return _HomeStateCard(
            key: const ValueKey('home-children-error'),
            icon: Icons.child_friendly_rounded,
            title: 'Данные детей недоступны',
            description: 'Билеты и покупка остаются доступны.',
            action: SecondaryButton(
              label: 'Повторить',
              onPressed: _childrenController.retry,
            ),
            compact: true,
          );
        }
        if (children.isEmpty) {
          return _HomeStateCard(
            key: const ValueKey('home-children-empty'),
            icon: Icons.child_care_rounded,
            title: 'Дети',
            description: 'Добавьте детей, чтобы быстрее оформлять визиты.',
            action: SecondaryButton(
              label: 'Открыть профиль',
              onPressed: () => _openRoot(AppRoutes.profile),
            ),
            compact: true,
          );
        }
        return SolidCard(
          key: const ValueKey('home-children-success'),
          child: Row(
            children: [
              const _HomeSectionIcon(icon: Icons.child_care_rounded),
              const SizedBox(width: SKSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Дети',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: SKSpacing.x1),
                    Text(
                      _childrenLabel(children),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Открыть профиль',
                onPressed: () => _openRoot(AppRoutes.profile),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBirthdaySection(BuildContext context) {
    return SolidCard(
      key: const ValueKey('home-birthday-cta'),
      child: Row(
        children: [
          const _HomeSectionIcon(icon: Icons.cake_rounded),
          const SizedBox(width: SKSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Планируете день рождения?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: SKSpacing.x1),
                Text(
                  'Посмотрите пакеты и оставьте заявку менеджеру.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Открыть раздел дней рождения',
            onPressed: () => _openRoot(AppRoutes.birthdays),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryBirthdaySection(BuildContext context) {
    return AnimatedBuilder(
      animation: _childrenController,
      builder: (context, _) {
        final primary = resolveHomePrimaryState(
          tickets: _issuedTickets,
          children: _childrenController.children,
          now: _nowProvider(),
        );
        if (primary.state == HomePrimaryState.birthday) {
          return const SizedBox.shrink();
        }
        return _buildBirthdaySection(context);
      },
    );
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

String _childrenLabel(List<Child> children) {
  final names = children.map((child) => child.name).take(3).join(', ');
  if (children.length <= 3) return names;
  return '$names и ещё ${children.length - 3}';
}

int _compareIssuedTickets(IssuedTicket a, IssuedTicket b) {
  if (a.visitDate == null && b.visitDate == null) return 0;
  if (a.visitDate == null) return 1;
  if (b.visitDate == null) return -1;
  return a.visitDate!.compareTo(b.visitDate!);
}

class _BirthdayHero extends StatelessWidget {
  const _BirthdayHero({
    super.key,
    required this.child,
    required this.nextBirthday,
    required this.birthdayAge,
    required this.now,
    required this.onOpen,
  });

  final Child child;
  final DateTime nextBirthday;
  final int birthdayAge;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final days = nextBirthday.difference(homeDateOnly(now)).inDays;
    final when = days == 0 ? 'сегодня' : 'через $days дней';
    return SolidCard(
      padding: const EdgeInsets.all(SKSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _HomeSectionIcon(icon: Icons.cake_rounded),
              const SizedBox(width: SKSpacing.x3),
              Expanded(
                child: Text(
                  '${child.name} скоро $birthdayAge лет',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: SKSpacing.x2),
          Text(
            'День рождения $when. Подберите праздник в Boom Bala.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: SKSpacing.x4),
          PrimaryButton(
            label: 'Посмотреть праздники',
            icon: Icons.arrow_forward_rounded,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

class _NewFamilyHero extends StatelessWidget {
  const _NewFamilyHero({
    super.key,
    required this.onBuy,
    this.returning = false,
    this.branchName,
  });

  final VoidCallback onBuy;
  final bool returning;
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    final branchLabel = branchName?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(SKRadius.xl),
      child: SizedBox(
        height: 264,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/home_hero_generated.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/home_hero.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(color: c.accentSoft),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    c.textPrimary.withValues(alpha: 0.82),
                    c.textPrimary.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(SKSpacing.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (branchLabel != null && branchLabel.isNotEmpty) ...[
                    Text(
                      branchLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                    ),
                    const SizedBox(height: SKSpacing.x3),
                  ],
                  Text(
                    returning
                        ? 'Готовы к следующему визиту?'
                        : 'Планируете посещение?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: SKSpacing.x2),
                  Text(
                    returning
                        ? 'Выберите дату и оформите следующий билет.'
                        : 'Выберите дату и оформите первый билет Boom Bala.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: 'Купить билет',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: onBuy,
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

class _HomeTicketCard extends StatelessWidget {
  const _HomeTicketCard({
    required this.ticket,
    required this.groupedCount,
    required this.onOpen,
    required this.onAllTickets,
  });

  final IssuedTicket ticket;
  final int groupedCount;
  final VoidCallback onOpen;
  final VoidCallback onAllTickets;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;
    final dateLabel = ticket.visitDate == null
        ? 'Дата уточняется'
        : DateFormat('dd.MM.yyyy').format(ticket.visitDate!);
    final countLabel = groupedCount > 1 ? '$groupedCount билета · ' : '';

    return SolidCard(
      padding: const EdgeInsets.all(SKSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineSmall,
                ),
              ),
              const SizedBox(width: SKSpacing.x2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SKSpacing.x2,
                  vertical: SKSpacing.x1,
                ),
                decoration: BoxDecoration(
                  color: c.successSoft,
                  borderRadius: BorderRadius.circular(SKRadius.sm),
                ),
                child: Text(
                  'Действует',
                  style: textTheme.labelMedium?.copyWith(color: c.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: SKSpacing.x4),
          _TicketMetaRow(
            icon: Icons.calendar_today_rounded,
            text: '$countLabel$dateLabel',
          ),
          const SizedBox(height: SKSpacing.x2),
          _TicketMetaRow(
            icon: Icons.location_on_outlined,
            text: ticket.branchName,
          ),
          const SizedBox(height: SKSpacing.x2),
          _TicketMetaRow(
            icon: Icons.confirmation_num_outlined,
            text: ticket.ticketNumber,
          ),
          const SizedBox(height: SKSpacing.x4),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Открыть билет',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onOpen,
                ),
              ),
              const SizedBox(width: SKSpacing.x2),
              TextButton(
                onPressed: onAllTickets,
                child: const Text('Все билеты'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketMetaRow extends StatelessWidget {
  const _TicketMetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: c.textTertiary),
        const SizedBox(width: SKSpacing.x2),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// A small set of real entry points keeps discovery useful without turning
/// Home into a catalogue. Each tile leads to an existing route.
class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions({
    required this.onBranchTap,
    required this.onBirthdayTap,
    required this.onMenuTap,
    required this.onContactsTap,
  });

  final VoidCallback onBranchTap;
  final VoidCallback onBirthdayTap;
  final VoidCallback onMenuTap;
  final VoidCallback onContactsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StarKidsSectionHeader(title: 'Быстрые действия'),
        const SizedBox(height: SKSpacing.x3),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: SKSpacing.x3,
          mainAxisSpacing: SKSpacing.x3,
          // Keep enough vertical room for the two-line editorial copy on
          // compact simulator/test widths.
          childAspectRatio: 1.05,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _QuickActionTile(
              icon: Icons.map_outlined,
              title: 'Филиал и маршрут',
              subtitle: 'Как доехать и что внутри',
              gradientColors: const [Color(0xFFFFE4DE), Color(0xFFFFF3E7)],
              onTap: onBranchTap,
            ),
            _QuickActionTile(
              icon: Icons.cake_outlined,
              title: 'Дни рождения',
              subtitle: 'Пакеты и заявка',
              gradientColors: const [Color(0xFFFFE0E8), Color(0xFFFFF0F4)],
              onTap: onBirthdayTap,
            ),
            _QuickActionTile(
              icon: Icons.restaurant_outlined,
              title: 'Меню',
              subtitle: 'Еда и напитки',
              gradientColors: const [Color(0xFFE7F0F4), Color(0xFFF3F8F8)],
              onTap: onMenuTap,
            ),
            _QuickActionTile(
              icon: Icons.phone_outlined,
              title: 'Контакты',
              subtitle: 'WhatsApp и звонок',
              gradientColors: const [Color(0xFFE8E4F5), Color(0xFFF6F3FA)],
              onTap: onContactsTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _HomeFeaturedPackage extends StatelessWidget {
  const _HomeFeaturedPackage({required this.package, required this.onOpen});

  final BirthdayPackage package;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StarKidsSectionHeader(
          title: 'Главный пакет',
          actionLabel: 'Все пакеты',
          onActionTap: onOpen,
        ),
        const SizedBox(height: SKSpacing.x3),
        StarKidsBirthdayPackageCard(
          title: package.name,
          priceLabel: package.priceLabel,
          guestLabel: package.guestLabel,
          description: package.description,
          highlights: package.highlights,
          imagePath: package.imagePath,
          isFeatured: package.isFeatured,
          compact: true,
          onActionTap: onOpen,
        ),
      ],
    );
  }
}

class _HomeStateCard extends StatelessWidget {
  const _HomeStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    this.secondaryAction,
    this.showProgress = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  final Widget? secondaryAction;
  final bool showProgress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SolidCard(
      padding: EdgeInsets.all(compact ? SKSpacing.x3 : SKSpacing.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeSectionIcon(icon: icon),
          const SizedBox(width: SKSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: SKSpacing.x1),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (showProgress) ...[
                  const SizedBox(height: SKSpacing.x3),
                  const LinearProgressIndicator(minHeight: 3),
                ],
                if (action != null) ...[
                  const SizedBox(height: SKSpacing.x3),
                  action!,
                ],
                if (secondaryAction != null) ...[
                  const SizedBox(height: SKSpacing.x2),
                  secondaryAction!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSectionIcon extends StatelessWidget {
  const _HomeSectionIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(SKRadius.md),
      ),
      child: Icon(icon, color: c.accent),
    );
  }
}

class _HomePromotions extends StatelessWidget {
  const _HomePromotions({required this.promotions});

  final List<PromotionOffer> promotions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StarKidsSectionHeader(title: 'Для вашей следующей поездки'),
        const SizedBox(height: SKSpacing.x3),
        ...promotions.take(2).map(
              (promotion) => Padding(
                padding: const EdgeInsets.only(bottom: SKSpacing.x3),
                child: SolidCard(
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.promotions),
                  child: Row(
                    children: [
                      const _HomeSectionIcon(icon: Icons.local_offer_outlined),
                      const SizedBox(width: SKSpacing.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              promotion.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: SKSpacing.x1),
                            Text(
                              promotion.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
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
            'Boom Bala',
            style: SKTextStyles.h1.copyWith(color: c.textPrimary),
          ),
        ),
        Divider(color: c.hairline, height: 1, thickness: 0.5),
        const SizedBox(height: SKSpacing.x2),
        GlassDrawerRow(
          icon: Icons.person_outline_rounded,
          label: 'Профиль',
          onTap: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.pushReplacementNamed(AppRoutes.profile);
          },
        ),
        GlassDrawerRow(
          icon: Icons.storefront_outlined,
          label: 'О филиале',
          onTap: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.pushNamed(AppRoutes.branchDetails);
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
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.pushReplacementNamed(AppRoutes.promotions);
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The tile is intentionally compact on phones and narrow test surfaces;
    // this prevents the editorial two-line copy from overflowing a 2-column
    // grid while retaining comfortable tap targets.
    final compact = MediaQuery.sizeOf(context).width < 500;

    return StarKidsReveal(
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
                  padding: EdgeInsets.all(
                    compact ? SKSpacing.x2 : SKSpacing.x3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: compact ? 34 : 42,
                        height: compact ? 34 : 42,
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
                      SizedBox(height: compact ? SKSpacing.x1 : SKSpacing.x3),
                      Text(
                        title,
                        maxLines: compact ? 1 : 2,
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
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: compact
                            ? textTheme.bodySmall?.copyWith(fontSize: 11)
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
                      border: Border.all(color: c.hairline, width: 0.5),
                    ),
                    child: Text(facility, style: textTheme.labelMedium),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: SKSpacing.x4),
          const Row(
            children: [
              Expanded(
                child: _TrustStat(title: '3 000', subtitle: 'м² пространства'),
              ),
              SizedBox(width: SKSpacing.x2),
              Expanded(
                child: _TrustStat(title: '12+', subtitle: 'лет работы'),
              ),
              SizedBox(width: SKSpacing.x2),
              Expanded(
                child: _TrustStat(title: '4.9', subtitle: 'рейтинг'),
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
