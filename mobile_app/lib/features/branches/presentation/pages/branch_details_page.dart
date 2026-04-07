import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_icon_sizes.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';

class BranchDetailsPage extends StatelessWidget {
  const BranchDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;
        final textTheme = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(title: Text(branch.shortLabel)),
          bottomNavigationBar: StarKidsBottomCtaBar(
        child: StarKidsButton.primary(
          label: 'Написать в WhatsApp',
          icon: Icons.chat_bubble_rounded,
          onPressed: () => _showMessage(
            context,
            'WhatsApp: ${branch.whatsAppPhone}',
          ),
        ),
          ),
          body: ListView(
        padding: const EdgeInsets.fromLTRB(
          StarKidsSpacing.xl,
          StarKidsSpacing.lg,
          StarKidsSpacing.xl,
          StarKidsSpacing.x5l,
        ),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: AspectRatio(
              aspectRatio: 2,
              child: Image.asset(
                branch.heroImagePath,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          Text(branch.name, style: textTheme.headlineMedium),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(branch.description, style: textTheme.bodyLarge),
          const SizedBox(height: StarKidsSpacing.lg),
          _InfoRow(
            icon: Icons.location_on_rounded,
            title: 'Адрес',
            value: branch.address,
          ),
          _InfoRow(
            icon: Icons.schedule_rounded,
            title: 'Режим работы',
            value: branch.workingHours,
          ),
          const SizedBox(height: StarKidsSpacing.lg),
          Row(
            children: [
              Expanded(
                child: StarKidsButton.secondary(
                  label: 'Маршрут',
                  icon: Icons.map_rounded,
                  onPressed: () => _showMessage(
                    context,
                    'Маршрут до филиала: ${branch.address}',
                  ),
                ),
              ),
              const SizedBox(width: StarKidsSpacing.md),
              Expanded(
                child: StarKidsButton.secondary(
                  label: 'Позвонить',
                  icon: Icons.call_rounded,
                  onPressed: () => _showMessage(
                    context,
                    'Телефон филиала: ${branch.phone}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: StarKidsSpacing.x2l),
          StarKidsSectionHeader(
            title: 'Почему родители выбирают этот филиал',
            description:
                'Короткая, понятная информация без перегруза перед заявкой или повторным визитом.',
          ),
          const SizedBox(height: StarKidsSpacing.md),
          Wrap(
            spacing: StarKidsSpacing.sm,
            runSpacing: StarKidsSpacing.sm,
            children: branch.facilities
                .map(
                  (facility) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StarKidsSpacing.md,
                      vertical: StarKidsSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: StarKidsColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      facility,
                      style: textTheme.labelMedium?.copyWith(
                        color: StarKidsColors.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: StarKidsSpacing.x2l),
          StarKidsSectionHeader(
            title: 'Галерея филиала',
            description: 'Реальные зоны, сцены и атмосфера площадки.',
          ),
          const SizedBox(height: StarKidsSpacing.md),
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final imagePath = branch.galleryImagePaths[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: Image.asset(imagePath, fit: BoxFit.cover),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: branch.galleryImagePaths.length,
            ),
          ),
        ],
          ),
        );
      },
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: StarKidsSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: StarKidsIconSizes.md,
            color: StarKidsColors.brandPrimary,
          ),
          const SizedBox(width: StarKidsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.labelMedium),
                const SizedBox(height: StarKidsSpacing.xs),
                Text(value, style: textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
