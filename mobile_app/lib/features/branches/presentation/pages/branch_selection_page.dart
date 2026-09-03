import 'package:flutter/material.dart';

import '../../../../core/design_system/sk_design_tokens.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/router/nested_navigation.dart';
import '../../../../core/design_system/widgets/star_kids_branch_card.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../../core/design_system/widgets/stable_future_builder.dart';
import '../../domain/branch_option.dart';

class BranchSelectionPage extends StatelessWidget {
  const BranchSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedBranchController = ServiceRegistry.selectedBranchController;

    return AnimatedBuilder(
      animation: selectedBranchController,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            leading: const NestedBackButton(),
            title: const Text('Выберите филиал'),
          ),
          body: SafeArea(
            child: StableFutureBuilder<List<BranchOption>>(
              cacheKey: 'branch-list',
              futureFactory: ServiceRegistry.branchRepository.listBranches,
              builder: (context, snapshot) {
                final branches = snapshot.data ?? const <BranchOption>[];
                final body = snapshot.connectionState ==
                            ConnectionState.waiting &&
                        branches.isEmpty
                    ? const Center(
                        key: ValueKey('branch-selection-loading'),
                        child: CircularProgressIndicator(),
                      )
                    : snapshot.hasError && branches.isEmpty
                        ? const _BranchSelectionStateView(
                            key: ValueKey('branch-selection-error'),
                            title: 'Филиалы пока недоступны',
                            description:
                                'Не удалось загрузить список филиалов. Попробуйте открыть экран позже.',
                          )
                        : ListView(
                            key: ValueKey(
                              'branch-selection-loaded-${branches.length}',
                            ),
                            padding: const EdgeInsets.all(SKSpacing.x5),
                            children: [
                              const StarKidsSectionHeader(
                                title: 'Начните с филиала',
                                description:
                                    'Филиал влияет на цены, акции, контакты и быстрые действия в приложении.',
                              ),
                              const SizedBox(height: SKSpacing.x5),
                              ...branches.asMap().entries.map(
                                    (entry) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: SKSpacing.x4,
                                      ),
                                      child: StarKidsBranchCard(
                                        revealDelay:
                                            starKidsStaggerDelay(entry.key),
                                        imagePath: entry.value.heroImagePath,
                                        title: entry.value.name,
                                        address: entry.value.address,
                                        workingHours: entry.value.workingHours,
                                        tagLabel: entry.value.id ==
                                                selectedBranchController
                                                    .selectedBranchId
                                            ? 'Выбран'
                                            : entry.value.shortLabel,
                                        onTap: () async {
                                          await selectedBranchController
                                              .selectBranch(
                                            entry.value.id,
                                          );

                                          if (!context.mounted) {
                                            return;
                                          }

                                          if (Navigator.of(context).canPop()) {
                                            Navigator.of(context).pop();
                                            return;
                                          }

                                          Navigator.of(
                                            context,
                                          ).pushReplacementNamed(
                                              AppRoutes.home);
                                        },
                                      ),
                                    ),
                                  ),
                            ],
                          );

                return StarKidsContentSwitcher(child: body);
              },
            ),
          ),
        );
      },
    );
  }
}

class _BranchSelectionStateView extends StatelessWidget {
  const _BranchSelectionStateView({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: SKSpacing.x10),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: SKSpacing.x2),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
