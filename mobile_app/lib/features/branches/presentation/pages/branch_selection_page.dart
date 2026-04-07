import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_branch_card.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
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
          appBar: AppBar(title: const Text('Выберите филиал')),
          body: SafeArea(
            child: FutureBuilder<List<BranchOption>>(
              future: ServiceRegistry.branchRepository.listBranches(),
              builder: (context, snapshot) {
                final branches = snapshot.data ?? const <BranchOption>[];

                return ListView(
                  padding: const EdgeInsets.all(StarKidsSpacing.xl),
                  children: [
                    const StarKidsSectionHeader(
                      title: 'Начните с филиала',
                      description:
                          'Филиал влияет на цены, акции, контакты и быстрые действия в приложении.',
                    ),
                    const SizedBox(height: StarKidsSpacing.xl),
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        branches.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else if (snapshot.hasError && branches.isEmpty)
                      const _BranchSelectionStateView(
                        title: 'Филиалы пока недоступны',
                        description:
                            'Не удалось загрузить список филиалов. Попробуйте открыть экран позже.',
                      )
                    else
                      ...branches.map(
                        (branch) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: StarKidsSpacing.lg),
                          child: StarKidsBranchCard(
                            imagePath: branch.heroImagePath,
                            title: branch.name,
                            address: branch.address,
                            workingHours: branch.workingHours,
                            tagLabel: branch.id ==
                                    selectedBranchController.selectedBranchId
                                ? 'Выбран'
                                : branch.shortLabel,
                            onTap: () async {
                              await selectedBranchController.selectBranch(
                                branch.id,
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
                              ).pushReplacementNamed(AppRoutes.home);
                            },
                          ),
                        ),
                      ),
                  ],
                );
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
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: StarKidsSpacing.x4l),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: StarKidsSpacing.sm),
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
