import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/widgets/star_kids_root_navigation.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/glass_floating_button.dart';
import '../../../../core/design_system/widgets/sk_hero.dart';
import '../../../../core/design_system/widgets/star_kids_birthday_package_card.dart';
import '../../../../core/design_system/widgets/star_kids_content_block_card.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../../core/design_system/widgets/stable_future_builder.dart';
import '../../../branches/domain/branch_option.dart';
import '../../../content/domain/public_content_block.dart';
import '../../../requests/domain/request_type.dart';
import '../../../requests/presentation/models/request_page_args.dart';
import '../../domain/birthday_package.dart';

class BirthdaysPage extends StatelessWidget {
  const BirthdaysPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;
        return Scaffold(
          extendBody: true,
          appBar: GlassAppBar(
            leading: const SizedBox(width: 44),
            title: Text(
              'Дни рождения',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: GlassIconButton(
              icon: Icons.swap_horiz_rounded,
              tooltip: 'Сменить филиал',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.branchSelection),
            ),
          ),
          bottomNavigationBar:
              const StarKidsRootNavigation(current: 'birthdays'),
          body: Stack(
            children: [
              StableFutureBuilder<_BirthdaysScreenData>(
                cacheKey: branch.id,
                futureFactory: () => _loadScreenData(branch.id),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final resolvedBranch = data?.branch ?? branch;
                  final packages = data?.packages ?? const <BirthdayPackage>[];

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      packages.isEmpty) {
                    return const StarKidsContentSwitcher(
                      child: Center(
                        key: ValueKey('birthdays-loading'),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError && packages.isEmpty) {
                    return const StarKidsContentSwitcher(
                      child: _BirthdaysStateView(
                        key: ValueKey('birthdays-error'),
                        title: 'Пакеты пока недоступны',
                        description:
                            'Не удалось загрузить live-данные по пакетам праздника. Попробуйте открыть экран позже.',
                      ),
                    );
                  }

                  if (packages.isEmpty) {
                    return const StarKidsContentSwitcher(
                      child: _BirthdaysStateView(
                        key: ValueKey('birthdays-empty'),
                        title: 'Пакеты скоро появятся',
                        description:
                            'Для выбранного филиала пока нет опубликованных пакетов. Можно оставить общую заявку, и менеджер подберет формат вручную.',
                      ),
                    );
                  }

                  return StarKidsContentSwitcher(
                    child: ListView(
                      key: ValueKey('birthdays-loaded-${resolvedBranch.id}'),
                      padding: EdgeInsets.fromLTRB(
                        SKSpacing.x5,
                        SKSpacing.x4,
                        SKSpacing.x5,
                        MediaQuery.viewPaddingOf(context).bottom + 88,
                      ),
                      children: [
                        SkHero(
                          imageUrl:
                              'https://images.unsplash.com/photo-1530103862676-de8c9debad1d?auto=format&fit=crop&w=900&q=80',
                          aspectRatio: 5 / 4,
                          chip: resolvedBranch.shortLabel,
                          title: 'Праздник, который дети запомнят.',
                          italicText: 'запомнят',
                          meta:
                              'Игровая зона, аниматор, кафе и торт в одном сценарии.',
                        ),
                        const SizedBox(height: SKSpacing.x6),
                        const StarKidsSectionHeader(
                          title: 'Что входит',
                        ),
                        const SizedBox(height: SKSpacing.x4),
                        const Column(
                          children: [
                            _IncludedRow(
                              title: 'Аниматоры и шоу',
                              subtitle: 'Авторские программы под возраст',
                              icon: Icons.auto_awesome_rounded,
                            ),
                            _IncludedRow(
                              icon: Icons.sports_gymnastics_rounded,
                              title: 'Безлимит активити-парк',
                              subtitle: '3000 м² зон, лабиринты, батуты',
                            ),
                            _IncludedRow(
                              icon: Icons.cake_rounded,
                              title: 'Торт и угощения',
                              subtitle: 'Меню по бюджету',
                            ),
                            _IncludedRow(
                              icon: Icons.send_rounded,
                              title: 'Заявка без переписок',
                              subtitle: 'Менеджер свяжется в течение 30 мин',
                            ),
                          ],
                        ),
                        const SizedBox(height: SKSpacing.x6),
                        const StarKidsSectionHeader(
                          title: 'Пакеты',
                        ),
                        const SizedBox(height: SKSpacing.x3),
                        SizedBox(
                          height: 356,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: packages.length,
                            separatorBuilder: (_, __) => const SizedBox(
                              width: SKSpacing.x3,
                            ),
                            itemBuilder: (context, index) {
                              final package = packages[index];
                              return SizedBox(
                                width: 280,
                                child: StarKidsBirthdayPackageCard(
                                  revealDelay: starKidsStaggerDelay(index),
                                  title: package.name,
                                  priceLabel: package.priceLabel,
                                  guestLabel: package.guestLabel,
                                  description: package.description,
                                  highlights: package.highlights,
                                  imagePath: package.imagePath,
                                  isFeatured: package.isFeatured,
                                  compact: true,
                                  onActionTap: () =>
                                      Navigator.of(context).pushNamed(
                                    AppRoutes.requests,
                                    arguments: RequestPageArgs(
                                      initialType: RequestType.birthdayRequest,
                                      initialPackageId: package.id,
                                      initialPackage: package,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: SKSpacing.x5),
                        if (data?.contentBlocks.isNotEmpty == true) ...[
                          const StarKidsSectionHeader(
                            title: 'Полезно знать',
                          ),
                          const SizedBox(height: SKSpacing.x3),
                          ...data!.contentBlocks.asMap().entries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: SKSpacing.x3,
                                  ),
                                  child: StarKidsContentBlockCard(
                                    revealDelay:
                                        starKidsStaggerDelay(entry.key),
                                    title: entry.value.title,
                                    body: entry.value.body,
                                    label: entry.value.ctaLabel,
                                  ),
                                ),
                              ),
                        ] else ...[
                          const StarKidsSectionHeader(
                            title: 'Какой пакет подойдет',
                          ),
                          const SizedBox(height: SKSpacing.x3),
                          const SolidCard(
                            padding: EdgeInsets.all(SKSpacing.x4),
                            radius: SKRadius.xl,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ComparisonRow(
                                  title: 'Нужен быстрый семейный праздник',
                                  value: 'Выбирайте WOW PARTY',
                                ),
                                SizedBox(height: SKSpacing.x3),
                                _ComparisonRow(
                                  title: 'Нужен wow-эффект и шоу',
                                  value: 'Лучше всего подойдет STAR PARTY',
                                ),
                                SizedBox(height: SKSpacing.x3),
                                _ComparisonRow(
                                  title: 'Большая компания и семейный формат',
                                  value: 'Берите MAGIC PARTY',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: GlassFloatingButton(
                    label: 'Оставить заявку',
                    icon: Icons.arrow_forward_rounded,
                    margin: const EdgeInsets.fromLTRB(
                      SKSpacing.gutter,
                      0,
                      SKSpacing.gutter,
                      SKSpacing.x3,
                    ),
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRoutes.requests,
                      arguments: const RequestPageArgs(
                        initialType: RequestType.birthdayRequest,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_BirthdaysScreenData> _loadScreenData(String branchId) async {
    final branchFuture =
        ServiceRegistry.branchRepository.getBranch(branchId).catchError(
              (_) => ServiceRegistry.selectedBranchController.selectedBranch,
            );
    final packagesFuture = ServiceRegistry.birthdayPackageRepository
        .listPackages(branchId: branchId)
        .catchError((_) => const <BirthdayPackage>[]);
    final contentBlocksFuture = ServiceRegistry.publicContentRepository
        .listContentBlocks(surface: 'birthdays')
        .catchError((_) => const <PublicContentBlock>[]);

    final branch = await branchFuture;
    final packages = await packagesFuture;
    final contentBlocks = await contentBlocksFuture;
    ServiceRegistry.selectedBranchController.syncSelectedBranch(branch);

    return _BirthdaysScreenData(
      branch: branch,
      packages: packages,
      contentBlocks: contentBlocks,
    );
  }
}

class _IncludedRow extends StatelessWidget {
  const _IncludedRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: SKSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(SKRadius.lg),
            ),
            child: Icon(icon, size: 20, color: c.textPrimary),
          ),
          const SizedBox(width: SKSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SKTextStyles.bodyL.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: SKTextStyles.small.copyWith(
                    color: c.textSecondary,
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

class _BirthdaysStateView extends StatelessWidget {
  const _BirthdaysStateView({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SKSpacing.x5),
        child: Center(
          child: SolidCard(
            padding: const EdgeInsets.all(SKSpacing.x5),
            radius: SKRadius.xl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: SKSpacing.x2),
                Text(description, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.labelMedium),
        const SizedBox(height: SKSpacing.x1),
        Text(value, style: textTheme.bodyLarge),
      ],
    );
  }
}

class _BirthdaysScreenData {
  const _BirthdaysScreenData({
    required this.branch,
    required this.packages,
    required this.contentBlocks,
  });

  final BranchOption branch;
  final List<BirthdayPackage> packages;
  final List<PublicContentBlock> contentBlocks;
}
