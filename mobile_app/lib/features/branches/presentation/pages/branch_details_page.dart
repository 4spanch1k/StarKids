import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
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
          appBar: GlassAppBar(
            leading: GlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Назад',
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              branch.shortLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: GlassIconButton(
              icon: Icons.swap_horiz_rounded,
              tooltip: 'Сменить филиал',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.branchSelection),
            ),
          ),
          bottomNavigationBar: StarKidsBottomCtaBar(
            child: PrimaryButton(
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
                    SKSpacing.x5,
                    SKSpacing.x4,
                    SKSpacing.x5,
                    SKSpacing.x12,
                  ),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: AspectRatio(
                        aspectRatio: 2,
                        child: StarKidsMediaImage(
                          source: branchDetail.heroImagePath,
                          fallbackSource: 'assets/images/branch_hero.jpg',
                        ),
                      ),
                    ),
                    const SizedBox(height: SKSpacing.x4),
                    Text(branchDetail.name, style: textTheme.headlineMedium),
                    const SizedBox(height: SKSpacing.x2),
                    Text(
                      _displayValue(
                        branchDetail.description,
                        fallback:
                            'Подробное описание филиала скоро появится. Пока можно посмотреть контакты, меню и пакеты праздника.',
                      ),
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: SKSpacing.x4),
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
                    const SizedBox(height: SKSpacing.x4),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Маршрут',
                            icon: Icons.map_rounded,
                            fullWidth: true,
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
                        const SizedBox(width: SKSpacing.x3),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Позвонить',
                            icon: Icons.call_rounded,
                            fullWidth: true,
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
                    const SizedBox(height: SKSpacing.x6),
                    const StarKidsSectionHeader(
                      title: 'Еще полезно перед визитом',
                      description:
                          'Короткие переходы к важным коммерческим экранам без перегруза текущего филиала.',
                    ),
                    const SizedBox(height: SKSpacing.x3),
                    _ResponsiveDetailActions(
                      first: SecondaryButton(
                        label: 'Меню',
                        icon: Icons.restaurant_menu_rounded,
                        fullWidth: true,
                        onPressed: () =>
                            Navigator.of(context).pushNamed(AppRoutes.menu),
                      ),
                      second: SecondaryButton(
                        label: 'Контакты и маршрут',
                        icon: Icons.pin_drop_rounded,
                        fullWidth: true,
                        onPressed: () =>
                            Navigator.of(context).pushNamed(AppRoutes.contacts),
                      ),
                    ),
                    const SizedBox(height: SKSpacing.x3),
                    SecondaryButton(
                      label: 'Посмотреть пакеты праздника',
                      icon: Icons.cake_rounded,
                      fullWidth: true,
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.birthdays),
                    ),
                    const SizedBox(height: SKSpacing.x6),
                    const StarKidsSectionHeader(
                      title: 'Почему родители выбирают этот филиал',
                      description:
                          'Короткая, понятная информация без перегруза перед заявкой или повторным визитом.',
                    ),
                    const SizedBox(height: SKSpacing.x3),
                    if (branchDetail.facilities.isNotEmpty)
                      _FacilityChips(facilities: branchDetail.facilities)
                    else
                      const _BranchInlineStateCard(
                        title: 'Подробности филиала скоро появятся',
                        description:
                            'Сейчас здесь пока нет отдельного списка удобств, но остальные данные филиала уже доступны.',
                      ),
                    const SizedBox(height: SKSpacing.x6),
                    const StarKidsSectionHeader(
                      title: 'Галерея филиала',
                      description: 'Реальные зоны, сцены и атмосфера площадки.',
                    ),
                    const SizedBox(height: SKSpacing.x3),
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
                                child: StarKidsMediaImage(
                                  source: imagePath,
                                  fallbackSource:
                                      'assets/images/branch_hero.jpg',
                                ),
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

class _ResponsiveDetailActions extends StatelessWidget {
  const _ResponsiveDetailActions({
    required this.first,
    required this.second,
  });

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            children: [
              first,
              const SizedBox(height: SKSpacing.x3),
              second,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: SKSpacing.x3),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _FacilityChips extends StatelessWidget {
  const _FacilityChips({required this.facilities});

  final List<String> facilities;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = SKTheme.of(context).colors;

    return Wrap(
      spacing: SKSpacing.x2,
      runSpacing: SKSpacing.x2,
      children: facilities
          .map(
            (facility) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SKSpacing.x3,
                vertical: SKSpacing.x1,
              ),
              decoration: BoxDecoration(
                color: c.elevated,
                borderRadius: BorderRadius.circular(SKRadius.pill),
                border: Border.all(color: c.hairline, width: 0.5),
              ),
              child: Text(
                facility,
                style: textTheme.labelMedium?.copyWith(
                  color: c.textPrimary,
                ),
              ),
            ),
          )
          .toList(),
    );
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
    final c = SKTheme.of(context).colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: SKSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 24,
            color: c.cta,
          ),
          const SizedBox(width: SKSpacing.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.labelMedium),
                const SizedBox(height: SKSpacing.x1),
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
    final c = SKTheme.of(context).colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SKSpacing.x5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(SKSpacing.x5),
            decoration: BoxDecoration(
              color: c.elevated,
              borderRadius: BorderRadius.circular(SKRadius.xl),
              border: Border.all(color: c.hairline, width: 0.5),
            ),
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

class _BranchInlineStateCard extends StatelessWidget {
  const _BranchInlineStateCard({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final c = SKTheme.of(context).colors;

    return Container(
      padding: const EdgeInsets.all(SKSpacing.x4),
      decoration: BoxDecoration(
        color: c.elevated,
        borderRadius: BorderRadius.circular(SKRadius.lg),
        border: Border.all(color: c.hairline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SKSpacing.x2),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
