import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/widgets/star_kids_root_navigation.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
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
                          imageUrl: 'assets/images/birthday_hero.jpg',
                          aspectRatio: 5 / 4,
                          chip: resolvedBranch.shortLabel,
                          title: 'Праздник, который хочется повторить.',
                          italicText: 'повторить',
                          meta:
                              'Выберите пакет и оставьте заявку — команда поможет с деталями.',
                        ),
                        const SizedBox(height: SKSpacing.x6),
                        const StarKidsSectionHeader(
                          title: 'Пакеты',
                          description:
                              'Состав и стоимость указаны в каждом пакете.',
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
                            title: 'Нужна помощь с выбором?',
                          ),
                          const SizedBox(height: SKSpacing.x3),
                          const SolidCard(
                            padding: EdgeInsets.all(SKSpacing.x4),
                            radius: SKRadius.xl,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Оставьте заявку — менеджер поможет подобрать формат праздника.',
                                  style: TextStyle(fontSize: 16, height: 1.4),
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
