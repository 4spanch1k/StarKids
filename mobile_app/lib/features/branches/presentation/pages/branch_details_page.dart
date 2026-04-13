import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_icon_sizes.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_media_image.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../../core/services/external_link_service.dart';
import '../../../contacts/domain/branch_contact_links.dart';
import '../../domain/branch_option.dart';

class BranchDetailsPage extends StatelessWidget {
  const BranchDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;

        return Scaffold(
          appBar: AppBar(
            title: Text(branch.shortLabel),
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
              label: 'Написать в WhatsApp',
              icon: Icons.chat_bubble_rounded,
              onPressed: _hasValue(branch.whatsAppPhone)
                  ? () => _handleAction(
                      context,
                      () => ExternalLinkService.openWhatsApp(
                        branch.whatsAppPhone,
                      ),
                    )
                  : null,
            ),
          ),
          body: FutureBuilder<_BranchDetailsScreenData>(
            future: _loadScreenData(branch.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const StarKidsContentSwitcher(
                  child: Center(
                    key: ValueKey('branch-details-loading'),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const StarKidsContentSwitcher(
                  child: _BranchDetailsStateView(
                    key: ValueKey('branch-details-empty'),
                    title: 'Филиал пока недоступен',
                    description:
                        'Не удалось загрузить live-данные по выбранному филиалу. Попробуйте открыть экран позже.',
                  ),
                );
              }

              final textTheme = Theme.of(context).textTheme;
              final branchDetail = snapshot.data!.branch;
              final contactLinks = snapshot.data!.contactLinks;
              final canOpenMap = _hasValue(contactLinks.mapUrl);
              final canCall = _hasValue(branchDetail.phone);

              return StarKidsContentSwitcher(
                child: ListView(
                  key: ValueKey('branch-details-${branchDetail.id}'),
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
                        child: StarKidsMediaImage(
                          source: branchDetail.heroImagePath,
                        ),
                      ),
                    ),
                    const SizedBox(height: StarKidsSpacing.lg),
                    Text(branchDetail.name, style: textTheme.headlineMedium),
                    const SizedBox(height: StarKidsSpacing.sm),
                    Text(
                      _displayValue(
                        branchDetail.description,
                        fallback:
                            'Подробное описание филиала скоро появится. Пока можно посмотреть контакты, цены и пакеты праздника.',
                      ),
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: StarKidsSpacing.lg),
                    _InfoRow(
                      icon: Icons.location_on_rounded,
                      title: 'Адрес',
                      value: _displayValue(
                        branchDetail.address,
                        fallback: 'Уточняйте у менеджера',
                      ),
                    ),
                    _InfoRow(
                      icon: Icons.schedule_rounded,
                      title: 'Режим работы',
                      value: _displayValue(
                        branchDetail.workingHours,
                        fallback: 'Уточняйте у менеджера',
                      ),
                    ),
                    const SizedBox(height: StarKidsSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: StarKidsButton.secondary(
                            label: 'Маршрут',
                            icon: Icons.map_rounded,
                            onPressed: !canOpenMap
                                ? null
                                : () => _handleAction(
                                    context,
                                    () => ExternalLinkService.openMap(
                                      contactLinks.mapUrl,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: StarKidsSpacing.md),
                        Expanded(
                          child: StarKidsButton.secondary(
                            label: 'Позвонить',
                            icon: Icons.call_rounded,
                            onPressed: !canCall
                                ? null
                                : () => _handleAction(
                                    context,
                                    () => ExternalLinkService.openPhone(
                                      branchDetail.phone,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: StarKidsSpacing.x2l),
                    const StarKidsSectionHeader(
                      title: 'Еще полезно перед визитом',
                      description:
                          'Короткие переходы к важным коммерческим экранам без перегруза текущего филиала.',
                    ),
                    const SizedBox(height: StarKidsSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: StarKidsButton.secondary(
                            label: 'Цены и правила',
                            icon: Icons.receipt_long_rounded,
                            onPressed: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.pricesRules),
                          ),
                        ),
                        const SizedBox(width: StarKidsSpacing.md),
                        Expanded(
                          child: StarKidsButton.secondary(
                            label: 'Контакты и маршрут',
                            icon: Icons.pin_drop_rounded,
                            onPressed: () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.contacts),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: StarKidsSpacing.md),
                    StarKidsButton.secondary(
                      label: 'Посмотреть пакеты праздника',
                      icon: Icons.cake_rounded,
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.birthdays),
                    ),
                    const SizedBox(height: StarKidsSpacing.x2l),
                    const StarKidsSectionHeader(
                      title: 'Почему родители выбирают этот филиал',
                      description:
                          'Короткая, понятная информация без перегруза перед заявкой или повторным визитом.',
                    ),
                    const SizedBox(height: StarKidsSpacing.md),
                    if (branchDetail.facilities.isNotEmpty)
                      Wrap(
                        spacing: StarKidsSpacing.sm,
                        runSpacing: StarKidsSpacing.sm,
                        children: branchDetail.facilities
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
                      )
                    else
                      const _BranchInlineStateCard(
                        title: 'Подробности филиала скоро появятся',
                        description:
                            'Сейчас здесь пока нет отдельного списка удобств, но остальные данные филиала уже доступны.',
                      ),
                    const SizedBox(height: StarKidsSpacing.x2l),
                    const StarKidsSectionHeader(
                      title: 'Галерея филиала',
                      description: 'Реальные зоны, сцены и атмосфера площадки.',
                    ),
                    const SizedBox(height: StarKidsSpacing.md),
                    if (branchDetail.galleryImagePaths.isNotEmpty)
                      SizedBox(
                        height: 156,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (context, index) {
                            final imagePath =
                                branchDetail.galleryImagePaths[index];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: AspectRatio(
                                aspectRatio: 4 / 5,
                                child: StarKidsMediaImage(source: imagePath),
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemCount: branchDetail.galleryImagePaths.length,
                        ),
                      )
                    else
                      const _BranchInlineStateCard(
                        title: 'Галерея скоро появится',
                        description:
                            'Для этого филиала еще не опубликованы изображения. Контакты и основные условия уже доступны.',
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

  Future<_BranchDetailsScreenData> _loadScreenData(String branchId) async {
    final branch = await ServiceRegistry.branchRepository.getBranch(branchId);
    ServiceRegistry.selectedBranchController.syncSelectedBranch(branch);
    final contactLinks = await ServiceRegistry.contactLinksRepository
        .getForBranch(branchId)
        .catchError((_) => _buildFallbackContactLinks(branch));

    return _BranchDetailsScreenData(branch: branch, contactLinks: contactLinks);
  }

  BranchContactLinks _buildFallbackContactLinks(BranchOption branch) {
    return BranchContactLinks(
      branchId: branch.id,
      address: branch.address,
      phone: branch.phone,
      whatsAppPhone: branch.whatsAppPhone,
      mapUrl: '',
      routeLabel: '',
      parkingHint: null,
      arrivalHint: null,
    );
  }

  static bool _hasValue(String? value) {
    return value?.trim().isNotEmpty == true;
  }

  static String _displayValue(String? value, {required String fallback}) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return fallback;
    }

    return normalized;
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

class _BranchDetailsScreenData {
  const _BranchDetailsScreenData({
    required this.branch,
    required this.contactLinks,
  });

  final BranchOption branch;
  final BranchContactLinks contactLinks;
}

class _BranchDetailsStateView extends StatelessWidget {
  const _BranchDetailsStateView({
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
              borderRadius: BorderRadius.circular(32),
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

class _BranchInlineStateCard extends StatelessWidget {
  const _BranchInlineStateCard({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: StarKidsColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
