import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_branch_card.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../data/branch_seed_data.dart';

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
            child: ListView(
              padding: const EdgeInsets.all(StarKidsSpacing.xl),
              children: [
                const StarKidsSectionHeader(
                  title: 'Начните с филиала',
                  description:
                      'Филиал влияет на цены, акции, контакты и быстрые действия в приложении.',
                ),
                const SizedBox(height: StarKidsSpacing.xl),
                ...branchSeedData.map(
                  (branch) => Padding(
                    padding: const EdgeInsets.only(bottom: StarKidsSpacing.lg),
                    child: StarKidsBranchCard(
                      imagePath: branch.heroImagePath,
                      title: branch.name,
                      address: branch.address,
                      workingHours: branch.workingHours,
                      tagLabel: branch.id == selectedBranchController.selectedBranchId
                          ? 'Выбран'
                          : branch.shortLabel,
                      onTap: () async {
                        await selectedBranchController.selectBranch(branch.id);

                        if (!context.mounted) {
                          return;
                        }

                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                          return;
                        }

                        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
