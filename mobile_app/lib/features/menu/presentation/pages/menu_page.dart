import 'package:flutter/material.dart';

import '../../../../core/design_system/sk_design_tokens.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/sk_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/star_kids_media_image.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/stable_future_builder.dart';
import '../../../branches/domain/branch_option.dart';
import '../../domain/branch_menu.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  int _selectedCategoryIndex = 0;
  final Map<String, GlobalKey> _categoryKeys = <String, GlobalKey>{};

  GlobalKey _keyForCategory(String id) {
    return _categoryKeys.putIfAbsent(id, GlobalKey.new);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;

        return Scaffold(
          appBar: GlassAppBar(
            title: Text(
              'Меню',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: GlassIconButton(
              icon: Icons.swap_horiz_rounded,
              tooltip: 'Сменить филиал',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.branchSelection),
            ),
          ),
          body: StableFutureBuilder<_MenuScreenData>(
            cacheKey: branch.id,
            futureFactory: () => _loadScreenData(branch.id),
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

              final categories = data.menu.categories;
              if (_selectedCategoryIndex >= categories.length) {
                _selectedCategoryIndex = 0;
              }

              return StarKidsContentSwitcher(
                child: CustomScrollView(
                  key: ValueKey('menu-loaded-${data.branch.id}'),
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        SK.s5,
                        SK.s5,
                        SK.s5,
                        SK.s7,
                      ),
                      sliver: SliverList.list(
                        children: [
                          StarKidsReveal(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${data.branch.shortLabel} · 11:00 — 23:00'
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'GeistMono',
                                    fontSize: 11,
                                    letterSpacing: 1.32,
                                    color: SK.ink3,
                                  ),
                                ),
                                const SizedBox(height: SK.s3),
                                const Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: 'Перекус '),
                                      TextSpan(
                                        text: 'между играми.',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'Fraunces',
                                    fontSize: 34,
                                    height: 1.05,
                                    letterSpacing: -0.85,
                                    color: SK.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _MenuChipHeader(
                        categories: categories,
                        selectedIndex: _selectedCategoryIndex,
                        onSelected: (index) {
                          setState(() => _selectedCategoryIndex = index);
                          final key = _keyForCategory(categories[index].id);
                          final context = key.currentContext;
                          if (context != null) {
                            Scrollable.ensureVisible(
                              context,
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        SK.s5,
                        SK.s4,
                        SK.s5,
                        SK.s8,
                      ),
                      sliver: SliverList.separated(
                        itemCount: categories.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: SK.s7),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return KeyedSubtree(
                            key: _keyForCategory(category.id),
                            child: _MenuCategorySection(
                              revealDelay: starKidsStaggerDelay(index),
                              category: category,
                            ),
                          );
                        },
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
    final branchFuture =
        ServiceRegistry.branchRepository.getBranch(branchId).catchError(
              (_) => ServiceRegistry.selectedBranchController.selectedBranch,
            );
    final menuFuture = ServiceRegistry.menuRepository.getForBranch(branchId);

    final branch = await branchFuture;
    final menu = await menuFuture;
    ServiceRegistry.selectedBranchController.syncSelectedBranch(branch);

    return _MenuScreenData(branch: branch, menu: menu);
  }
}

class _MenuChipHeader extends SliverPersistentHeaderDelegate {
  const _MenuChipHeader({
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<MenuCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? SK.darkBg : SK.bg,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: SK.s5, vertical: SK.s2),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: SK.s2),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: Material(
              color: selected
                  ? (isDark ? SK.darkInk : SK.accent2)
                  : (isDark ? SK.darkBgElev : SK.bgElev),
              borderRadius: BorderRadius.circular(SK.rPill),
              child: InkWell(
                borderRadius: BorderRadius.circular(SK.rPill),
                onTap: () => onSelected(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SK.s4,
                    vertical: SK.s2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SK.rPill),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : (isDark ? SK.darkLine : SK.line),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    categories[index].title,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      color: selected
                          ? (isDark ? SK.darkBg : SK.bg)
                          : (isDark ? SK.darkInk : SK.ink),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MenuChipHeader oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.categories != categories;
  }
}

class _MenuCategorySection extends StatelessWidget {
  const _MenuCategorySection({
    required this.category,
    this.revealDelay = Duration.zero,
  });

  final MenuCategory category;
  final Duration revealDelay;

  @override
  Widget build(BuildContext context) {
    return StarKidsReveal(
      delay: revealDelay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: category.title,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 22,
                    height: 1.1,
                    letterSpacing: -0.44,
                    color: SK.ink,
                  ),
                ),
                TextSpan(
                  text: ' · ${category.items.length}',
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 13,
                    color: SK.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SK.s4),
          Column(
            children: [
              for (final item in category.items) ...[
                _MenuItemCard(item: item),
                const SizedBox(height: SK.s2),
              ],
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? SK.darkBgElev : SK.bgElev,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? SK.darkLine : SK.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 64,
              child: StarKidsMediaImage(
                source: item.imageUrl.isEmpty
                    ? _redesignMenuImage(item.title)
                    : item.imageUrl,
                fallbackSource: _redesignMenuImage(item.title),
              ),
            ),
          ),
          const SizedBox(width: SKSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: SKSpacing.x2),
                Row(
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _formatPriceNumber(item.priceTenge),
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.32,
                              color: c.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: ' ₸',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 12,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? SK.darkBgSoft : SK.accentSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: SK.accent,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPriceNumber(int price) {
    final s = price.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

String _redesignMenuImage(String title) {
  const images = <String, String>{
    'Куриный суп с домашней лапшой':
        'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=300&q=80',
    'Суп ребра':
        'https://images.unsplash.com/photo-1604152135912-04a022e23696?auto=format&fit=crop&w=300&q=80',
    'Пельмени с говядиной':
        'https://images.unsplash.com/photo-1626804475297-41608ea09aeb?auto=format&fit=crop&w=300&q=80',
    'Пельмени с курицей':
        'https://images.unsplash.com/photo-1518983546435-91f8b87fe561?auto=format&fit=crop&w=300&q=80',
    'Хрустящие баклажаны':
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=300&q=80',
    'Цезарь с курицей':
        'https://images.unsplash.com/photo-1551248429-40975aa4de74?auto=format&fit=crop&w=300&q=80',
    'Греческий':
        'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=300&q=80',
    'Свежий микс':
        'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=300&q=80',
    'Пепперони':
        'https://images.unsplash.com/photo-1628840042765-356cda07504e?auto=format&fit=crop&w=300&q=80',
    'Маргарита':
        'https://images.unsplash.com/photo-1604068549290-dea0e4a305ca?auto=format&fit=crop&w=300&q=80',
    'Болоньезе':
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=300&q=80',
    '4 сезона':
        'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?auto=format&fit=crop&w=300&q=80',
    '4 сыра':
        'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=300&q=80',
    'Манты домашние':
        'https://images.unsplash.com/photo-1585032226651-759b368d7246?auto=format&fit=crop&w=300&q=80',
    'Курица в соусе терияки':
        'https://images.unsplash.com/photo-1532550907401-a500c9a57435?auto=format&fit=crop&w=300&q=80',
    'Сырная паста':
        'https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=300&q=80',
    'Чизбургер Beef':
        'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=300&q=80',
    'Наггетсы':
        'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=300&q=80',
    'Сырные палочки':
        'https://images.unsplash.com/photo-1531749668029-2db88e4276c7?auto=format&fit=crop&w=300&q=80',
    'Крылышки (16 шт)':
        'https://images.unsplash.com/photo-1608039755401-742074f0548d?auto=format&fit=crop&w=300&q=80',
    'Фри':
        'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&w=300&q=80',
    'Чёрный / Зелёный':
        'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=300&q=80',
    'Чай с молоком':
        'https://images.unsplash.com/photo-1545487343-5b5f2da9ffbb?auto=format&fit=crop&w=300&q=80',
    'Ташкентский / Ягодный':
        'https://images.unsplash.com/photo-1597318181409-cf64d0b5d8a2?auto=format&fit=crop&w=300&q=80',
  };
  return images[title] ??
      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=300&q=80';
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
        padding: const EdgeInsets.all(SKSpacing.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: SKSpacing.x3),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: SKSpacing.x4),
            SecondaryButton(
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
