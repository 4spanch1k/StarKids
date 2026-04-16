import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_content_block_card.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../../../core/services/external_link_service.dart';
import '../../../branches/domain/branch_option.dart';
import '../../../content/domain/public_content_block.dart';
import '../../../requests/domain/request_type.dart';
import '../../../requests/presentation/models/request_page_args.dart';
import '../../domain/branch_contact_links.dart';

class ContactsMapPage extends StatelessWidget {
  const ContactsMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;

        return FutureBuilder<_ContactsScreenData>(
          future: _loadScreenData(branch.id),
          builder: (context, snapshot) {
            final contactLinks = snapshot.data?.contactLinks;
            final branchDetail = snapshot.data?.branch ?? branch;
            final canOpenWhatsApp =
                contactLinks != null && _hasValue(contactLinks.whatsAppPhone);
            final canOpenMap =
                contactLinks != null && _hasValue(contactLinks.mapUrl);
            final canCall =
                contactLinks != null && _hasValue(contactLinks.phone);

            return Scaffold(
              appBar: AppBar(
                title: const Text('Контакты и маршрут'),
                actions: [
                  IconButton(
                    tooltip: 'Сменить филиал',
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.branchSelection),
                    icon: const Icon(Icons.swap_horiz_rounded),
                  ),
                ],
              ),
              bottomNavigationBar: StarKidsBottomCtaBar(
                child: StarKidsButton.primary(
                  label: 'Написать в WhatsApp',
                  icon: Icons.chat_bubble_rounded,
                  onPressed: !canOpenWhatsApp
                      ? null
                      : () => _handleAction(
                            context,
                            () => ExternalLinkService.openWhatsApp(
                              contactLinks.whatsAppPhone,
                            ),
                          ),
                ),
              ),
              body: Builder(
                builder: (context) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const StarKidsContentSwitcher(
                      child: Center(
                        key: ValueKey('contacts-loading'),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return StarKidsContentSwitcher(
                      child: _ContactsStateView(
                        key: const ValueKey('contacts-error'),
                        title: 'Контакты пока недоступны',
                        description:
                            'Не удалось открыть контакты и маршрут для выбранного филиала. Попробуйте выбрать другой филиал.',
                        actionLabel: 'Сменить филиал',
                        onActionTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.branchSelection),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return StarKidsContentSwitcher(
                      child: _ContactsStateView(
                        key: const ValueKey('contacts-empty'),
                        title: 'Контакты пока недоступны',
                        description:
                            'Экран готов, но контакты и маршрут для выбранного филиала пока не удалось показать.',
                        actionLabel: 'Сменить филиал',
                        onActionTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.branchSelection),
                      ),
                    );
                  }

                  final textTheme = Theme.of(context).textTheme;
                  final contact = snapshot.data!.contactLinks;

                  return StarKidsContentSwitcher(
                    child: ListView(
                      key: ValueKey('contacts-loaded-${branchDetail.id}'),
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
                            borderRadius: BorderRadius.circular(
                              StarKidsRadii.hero,
                            ),
                            border: Border.all(
                              color: StarKidsColors.borderDefault,
                            ),
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
                                  borderRadius: BorderRadius.circular(
                                    StarKidsRadii.full,
                                  ),
                                ),
                                child: Text(
                                  branchDetail.shortLabel,
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
                            borderRadius: BorderRadius.circular(
                              StarKidsRadii.xl,
                            ),
                            border: Border.all(
                              color: StarKidsColors.borderDefault,
                            ),
                          ),
                          child: Column(
                            children: [
                              _ContactRow(
                                icon: Icons.location_on_rounded,
                                title: 'Адрес',
                                value: _displayValue(
                                  contact.address,
                                  fallback: branchDetail.address,
                                ),
                              ),
                              _ContactRow(
                                icon: Icons.schedule_rounded,
                                title: 'Режим работы',
                                value: _displayValue(
                                  branchDetail.workingHours,
                                  fallback: 'Уточняйте у менеджера',
                                ),
                              ),
                              _ContactRow(
                                icon: Icons.call_rounded,
                                title: 'Телефон',
                                value: _displayValue(
                                  contact.phone,
                                  fallback: 'Уточняйте у менеджера',
                                ),
                              ),
                              _ContactRow(
                                icon: Icons.chat_bubble_rounded,
                                title: 'WhatsApp',
                                value: _displayValue(
                                  contact.whatsAppPhone,
                                  fallback: 'Уточняйте у менеджера',
                                ),
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
                                onPressed: !canOpenMap
                                    ? null
                                    : () => _handleAction(
                                          context,
                                          () => ExternalLinkService.openMap(
                                            contact.mapUrl,
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
                                            contact.phone,
                                          ),
                                        ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: StarKidsSpacing.md),
                        StarKidsButton.secondary(
                          label: 'Написать в WhatsApp',
                          icon: Icons.chat_bubble_rounded,
                          onPressed: !canOpenWhatsApp
                              ? null
                              : () => _handleAction(
                                    context,
                                    () => ExternalLinkService.openWhatsApp(
                                      contact.whatsAppPhone,
                                    ),
                                  ),
                        ),
                        const SizedBox(height: StarKidsSpacing.xl),
                        Container(
                          padding: const EdgeInsets.all(StarKidsSpacing.lg),
                          decoration: BoxDecoration(
                            color: StarKidsColors.surfacePrimary,
                            borderRadius: BorderRadius.circular(
                              StarKidsRadii.xl,
                            ),
                            border: Border.all(
                              color: StarKidsColors.borderDefault,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Если неудобно говорить сейчас',
                                style: textTheme.titleLarge,
                              ),
                              const SizedBox(height: StarKidsSpacing.sm),
                              Text(
                                'Оставьте короткий запрос менеджеру. Мы добавим в сообщение контекст по выбранному филиалу, чтобы оператору было проще помочь без лишних уточнений.',
                                style: textTheme.bodyMedium,
                              ),
                              const SizedBox(height: StarKidsSpacing.lg),
                              StarKidsButton.secondary(
                                label: 'Оставить запрос менеджеру',
                                icon: Icons.support_agent_rounded,
                                onPressed: () =>
                                    Navigator.of(context).pushNamed(
                                  AppRoutes.requests,
                                  arguments: RequestPageArgs(
                                    initialType: RequestType.contact,
                                    initialContactContextLabel:
                                        'Филиал: ${branchDetail.name}',
                                    initialContactMessage:
                                        'Интересует филиал ${branchDetail.name}. Нужна помощь по маршруту, формату визита или свободным датам.',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: StarKidsSpacing.x2l),
                        Container(
                          padding: const EdgeInsets.all(StarKidsSpacing.lg),
                          decoration: BoxDecoration(
                            color: StarKidsColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(
                              StarKidsRadii.xl,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Как добраться',
                                style: textTheme.titleLarge,
                              ),
                              if (_hasValue(contact.routeLabel)) ...[
                                const SizedBox(height: StarKidsSpacing.sm),
                                Text(
                                  contact.routeLabel,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: StarKidsColors.brandPrimary,
                                  ),
                                ),
                              ],
                              if (_hasValue(contact.parkingHint)) ...[
                                const SizedBox(height: StarKidsSpacing.md),
                                Text(
                                  contact.parkingHint!,
                                  style: textTheme.bodyLarge,
                                ),
                              ],
                              if (_hasValue(contact.arrivalHint)) ...[
                                const SizedBox(height: StarKidsSpacing.sm),
                                Text(
                                  contact.arrivalHint!,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: StarKidsColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (!_hasValue(contact.routeLabel) &&
                                  !_hasValue(contact.parkingHint) &&
                                  !_hasValue(contact.arrivalHint)) ...[
                                const SizedBox(height: StarKidsSpacing.sm),
                                Text(
                                  'Маршрут и дополнительные подсказки скоро появятся для этого филиала.',
                                  style: textTheme.bodyLarge,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (snapshot.data!.contentBlocks.isNotEmpty) ...[
                          const SizedBox(height: StarKidsSpacing.x2l),
                          const StarKidsSectionHeader(
                            title: 'Что еще важно знать',
                            description:
                                'Дополнительные подсказки по маршруту и визиту приходят из live-контента админки.',
                          ),
                          const SizedBox(height: StarKidsSpacing.md),
                          ...snapshot.data!.contentBlocks.map(
                            (block) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: StarKidsSpacing.md,
                              ),
                              child: StarKidsContentBlockCard(
                                title: block.title,
                                body: block.body,
                                label: block.ctaLabel,
                              ),
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

  Future<_ContactsScreenData> _loadScreenData(String branchId) async {
    final branch = await ServiceRegistry.branchRepository.getBranch(branchId);
    ServiceRegistry.selectedBranchController.syncSelectedBranch(branch);
    final contactLinks = await ServiceRegistry.contactLinksRepository
        .getForBranch(branchId)
        .catchError((_) => _buildFallbackContactLinks(branch));
    final contentBlocks = await ServiceRegistry.publicContentRepository
        .listContentBlocks(surface: 'contacts')
        .catchError((_) => const <PublicContentBlock>[]);

    return _ContactsScreenData(
      branch: branch,
      contactLinks: contactLinks,
      contentBlocks: contentBlocks,
    );
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

class _ContactsScreenData {
  const _ContactsScreenData({
    required this.branch,
    required this.contactLinks,
    required this.contentBlocks,
  });

  final BranchOption branch;
  final BranchContactLinks contactLinks;
  final List<PublicContentBlock> contentBlocks;
}

class _ContactsStateView extends StatelessWidget {
  const _ContactsStateView({
    super.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onActionTap;

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
                const SizedBox(height: StarKidsSpacing.lg),
                StarKidsButton.secondary(
                  label: actionLabel,
                  icon: Icons.swap_horiz_rounded,
                  onPressed: onActionTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
