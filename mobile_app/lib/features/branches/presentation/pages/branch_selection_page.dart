import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_branch_card.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../data/branch_seed_data.dart';

class BranchSelectionPage extends StatelessWidget {
  const BranchSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                  tagLabel: branch.shortLabel,
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed(
                      AppRoutes.home,
                      arguments: branch.id,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
