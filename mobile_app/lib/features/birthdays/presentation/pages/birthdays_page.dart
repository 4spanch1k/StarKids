import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
import '../../../../core/design_system/widgets/star_kids_birthday_package_card.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_content_block_card.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
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
        final textTheme = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Дни рождения'),
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
              label: 'Оставить заявку на праздник',
              icon: Icons.cake_rounded,
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.requests,
                arguments: const RequestPageArgs(
                  initialType: RequestType.birthdayRequest,
                ),
              ),
            ),
          ),
          body: FutureBuilder<_BirthdaysScreenData>(
            future: _loadScreenData(branch.id),
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
                                    resolvedBranch.shortLabel,
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
                      children: _birthdayValueHighlights
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
                    ...packages.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: StarKidsSpacing.lg,
                        ),
                        child: StarKidsBirthdayPackageCard(
                          revealDelay: starKidsStaggerDelay(entry.key),
                          title: entry.value.name,
                          priceLabel: entry.value.priceLabel,
                          guestLabel: entry.value.guestLabel,
                          description: entry.value.description,
                          highlights: entry.value.highlights,
                          imagePath: entry.value.imagePath,
                          isFeatured: entry.value.isFeatured,
                          onActionTap: () => Navigator.of(context).pushNamed(
                            AppRoutes.requests,
                            arguments: RequestPageArgs(
                              initialType: RequestType.birthdayRequest,
                              initialPackageId: entry.value.id,
                              initialPackage: entry.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: StarKidsSpacing.xl),
                    if (data?.contentBlocks.isNotEmpty == true) ...[
                      const StarKidsSectionHeader(
                        title: 'Что важно по праздникам',
                        description:
                            'Этот блок управляется через live-контент и помогает быстро обновлять коммерческие акценты.',
                      ),
                      const SizedBox(height: StarKidsSpacing.md),
                      ...data!.contentBlocks.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: StarKidsSpacing.md,
                          ),
                          child: StarKidsContentBlockCard(
                            revealDelay: starKidsStaggerDelay(entry.key),
                            title: entry.value.title,
                            body: entry.value.body,
                            label: entry.value.ctaLabel,
                          ),
                        ),
                      ),
                    ] else ...[
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
                          border: Border.all(
                            color: StarKidsColors.borderDefault,
                          ),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ComparisonRow(
                              title: 'Нужен быстрый семейный праздник',
                              value: 'Выбирайте WOW PARTY',
                            ),
                            SizedBox(height: StarKidsSpacing.md),
                            _ComparisonRow(
                              title: 'Нужен wow-эффект и шоу',
                              value: 'Лучше всего подойдет STAR PARTY',
                            ),
                            SizedBox(height: StarKidsSpacing.md),
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
        );
      },
    );
  }

  Future<_BirthdaysScreenData> _loadScreenData(String branchId) async {
    final branch = await ServiceRegistry.branchRepository
        .getBranch(branchId)
        .catchError(
          (_) => ServiceRegistry.selectedBranchController.selectedBranch,
        );
    ServiceRegistry.selectedBranchController.syncSelectedBranch(branch);
    final packages = await ServiceRegistry.birthdayPackageRepository
        .listPackages(branchId: branchId)
        .catchError((_) => const <BirthdayPackage>[]);
    final contentBlocks = await ServiceRegistry.publicContentRepository
        .listContentBlocks(surface: 'birthdays')
        .catchError((_) => const <PublicContentBlock>[]);

    return _BirthdaysScreenData(
      branch: branch,
      packages: packages,
      contentBlocks: contentBlocks,
    );
  }
}

const _birthdayValueHighlights = <String>[
  'Аниматоры и шоу',
  'Безлимитный активити парк',
  'Пакеты под разный бюджет',
  'Быстрая заявка без долгой переписки',
];

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
        const SizedBox(height: StarKidsSpacing.xs),
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
