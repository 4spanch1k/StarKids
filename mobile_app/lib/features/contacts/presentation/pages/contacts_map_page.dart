import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../../core/services/external_link_service.dart';
import '../../data/seed_contact_links_repository.dart';
import '../../domain/branch_contact_links.dart';

class ContactsMapPage extends StatelessWidget {
  const ContactsMapPage({super.key});

  static const SeedContactLinksRepository _repository =
      SeedContactLinksRepository();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;

        return Scaffold(
          appBar: AppBar(title: const Text('Контакты и маршрут')),
          bottomNavigationBar: StarKidsBottomCtaBar(
            child: StarKidsButton.primary(
              label: 'Написать в WhatsApp',
              icon: Icons.chat_bubble_rounded,
              onPressed: () => _handleAction(
                context,
                () => ExternalLinkService.openWhatsApp(branch.whatsAppPhone),
              ),
            ),
          ),
          body: FutureBuilder<BranchContactLinks>(
            future: _repository.getForBranch(branch.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return const _ContactsStateView(
                  title: 'Контакты пока недоступны',
                  description:
                      'Экран готов, но контакты и маршрут для выбранного филиала пока не удалось показать.',
                );
              }

              final contactLinks = snapshot.data!;
              final textTheme = Theme.of(context).textTheme;

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  StarKidsSpacing.xl,
                  StarKidsSpacing.lg,
                  StarKidsSpacing.xl,
                  StarKidsSpacing.x5l,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(StarKidsSpacing.xl),
                    decoration: BoxDecoration(
                      color: StarKidsColors.surfacePrimary,
                      borderRadius: BorderRadius.circular(StarKidsRadii.hero),
                      border: Border.all(color: StarKidsColors.borderDefault),
                      boxShadow: StarKidsShadows.depth1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: StarKidsSpacing.md,
                            vertical: StarKidsSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: StarKidsColors.surfaceTertiary,
                            borderRadius:
                                BorderRadius.circular(StarKidsRadii.full),
                          ),
                          child: Text(
                            branch.shortLabel,
                            style: textTheme.labelMedium?.copyWith(
                              color: StarKidsColors.brandPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: StarKidsSpacing.md),
                        Text(
                          'Контакты и маршрут должны быть понятны за несколько секунд.',
                          style: textTheme.headlineMedium,
                        ),
                        const SizedBox(height: StarKidsSpacing.md),
                        Text(
                          'Родитель должен быстро открыть карту, позвонить или написать в WhatsApp без лишних переходов.',
                          style: textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: StarKidsSpacing.x2l),
                  const StarKidsSectionHeader(
                    title: 'Все, что нужно перед визитом',
                    description:
                        'Один экран с адресом, режимом работы и быстрыми способами связи.',
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(StarKidsSpacing.lg),
                    decoration: BoxDecoration(
                      color: StarKidsColors.surfacePrimary,
                      borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                      border: Border.all(color: StarKidsColors.borderDefault),
                    ),
                    child: Column(
                      children: [
                        _ContactRow(
                          icon: Icons.location_on_rounded,
                          title: 'Адрес',
                          value: branch.address,
                        ),
                        _ContactRow(
                          icon: Icons.schedule_rounded,
                          title: 'Режим работы',
                          value: branch.workingHours,
                        ),
                        _ContactRow(
                          icon: Icons.call_rounded,
                          title: 'Телефон',
                          value: branch.phone,
                        ),
                        _ContactRow(
                          icon: Icons.chat_bubble_rounded,
                          title: 'WhatsApp',
                          value: branch.whatsAppPhone,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: StarKidsButton.secondary(
                          label: 'Построить маршрут',
                          icon: Icons.map_rounded,
                          onPressed: () => _handleAction(
                            context,
                            () => ExternalLinkService.openMap(
                                contactLinks.mapUrl),
                          ),
                        ),
                      ),
                      const SizedBox(width: StarKidsSpacing.md),
                      Expanded(
                        child: StarKidsButton.secondary(
                          label: 'Позвонить',
                          icon: Icons.call_rounded,
                          onPressed: () => _handleAction(
                            context,
                            () => ExternalLinkService.openPhone(branch.phone),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: StarKidsSpacing.md),
                  StarKidsButton.secondary(
                    label: 'Написать в WhatsApp',
                    icon: Icons.chat_bubble_rounded,
                    onPressed: () => _handleAction(
                      context,
                      () => ExternalLinkService.openWhatsApp(
                          branch.whatsAppPhone),
                    ),
                  ),
                  const SizedBox(height: StarKidsSpacing.x2l),
                  Container(
                    padding: const EdgeInsets.all(StarKidsSpacing.lg),
                    decoration: BoxDecoration(
                      color: StarKidsColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Как добраться',
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: StarKidsSpacing.sm),
                        Text(
                          contactLinks.routeLabel,
                          style: textTheme.labelMedium?.copyWith(
                            color: StarKidsColors.brandPrimary,
                          ),
                        ),
                        if (contactLinks.parkingHint != null) ...[
                          const SizedBox(height: StarKidsSpacing.md),
                          Text(
                            contactLinks.parkingHint!,
                            style: textTheme.bodyLarge,
                          ),
                        ],
                        if (contactLinks.arrivalHint != null) ...[
                          const SizedBox(height: StarKidsSpacing.sm),
                          Text(
                            contactLinks.arrivalHint!,
                            style: textTheme.bodyMedium?.copyWith(
                              color: StarKidsColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static Future<void> _handleAction(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    final success = await action();

    if (!context.mounted || success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Не удалось открыть ссылку. Попробуйте позже.'),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
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
          Icon(icon, color: StarKidsColors.brandPrimary),
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

class _ContactsStateView extends StatelessWidget {
  const _ContactsStateView({
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
