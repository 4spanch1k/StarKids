import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/sk_tokens.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
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
            final whatsAppPhone = contactLinks?.whatsAppPhone ?? '';
            final canOpenWhatsApp =
                contactLinks != null && _hasValue(contactLinks.whatsAppPhone);
            final canOpenMap =
                contactLinks != null && _hasValue(contactLinks.mapUrl);
            final canCall =
                contactLinks != null && _hasValue(contactLinks.phone);

            return Scaffold(
              appBar: GlassAppBar(
                title: Text(
                  'Контакты',
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
                child: _WhatsAppButton(
                  enabled: canOpenWhatsApp,
                  onTap: () => _handleAction(
                    context,
                    () => ExternalLinkService.openWhatsApp(whatsAppPhone),
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
                  final c = SKTheme.of(context).colors;
                  final contact = snapshot.data!.contactLinks;

                  return StarKidsContentSwitcher(
                    child: ListView(
                      key: ValueKey('contacts-loaded-${branchDetail.id}'),
                      padding: const EdgeInsets.fromLTRB(
                        SKSpacing.x5,
                        SKSpacing.x4,
                        SKSpacing.x5,
                        SKSpacing.x12,
                      ),
                      children: [
                        StarKidsReveal(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Star Kids · ${branchDetail.shortLabel}'
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'GeistMono',
                                  fontSize: 11,
                                  letterSpacing: 1.32,
                                  color: SK.ink3,
                                ),
                              ),
                              const SizedBox(height: SK.s3),
                              const Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: 'Связаться\n'),
                                    TextSpan(
                                      text: 'в один тап.',
                                      style: TextStyle(
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                                style: TextStyle(
                                  fontFamily: 'Fraunces',
                                  fontSize: 34,
                                  height: 1.05,
                                  letterSpacing: -0.85,
                                  color: SK.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: SKSpacing.x4),
                        const _MapPlaceholder(),
                        const SizedBox(height: SKSpacing.x5),
                        const StarKidsSectionHeader(title: 'Адрес и связь'),
                        const SizedBox(height: SKSpacing.x4),
                        Container(
                          padding: const EdgeInsets.all(SKSpacing.x4),
                          decoration: BoxDecoration(
                            color: c.elevated,
                            borderRadius: BorderRadius.circular(SKRadius.xl),
                            border: Border.all(color: c.hairline, width: 0.5),
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
                        const SizedBox(height: SKSpacing.x4),
                        Row(
                          children: [
                            Expanded(
                              child: SecondaryButton(
                                label: 'Построить маршрут',
                                icon: Icons.map_rounded,
                                fullWidth: true,
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
                                            contact.phone,
                                          ),
                                        ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SKSpacing.x3),
                        SecondaryButton(
                          label: 'Написать в WhatsApp',
                          icon: Icons.chat_bubble_rounded,
                          fullWidth: true,
                          onPressed: !canOpenWhatsApp
                              ? null
                              : () => _handleAction(
                                    context,
                                    () => ExternalLinkService.openWhatsApp(
                                      contact.whatsAppPhone,
                                    ),
                                  ),
                        ),
                        const SizedBox(height: SKSpacing.x5),
                        Container(
                          padding: const EdgeInsets.all(SKSpacing.x4),
                          decoration: BoxDecoration(
                            color: c.elevated,
                            borderRadius: BorderRadius.circular(SKRadius.xl),
                            border: Border.all(color: c.hairline, width: 0.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Оставить запрос менеджеру',
                                style: textTheme.titleLarge,
                              ),
                              const SizedBox(height: SKSpacing.x2),
                              Text(
                                'Опишите вопрос — перезвоним и поможем.',
                                style: textTheme.bodyMedium,
                              ),
                              const SizedBox(height: SKSpacing.x4),
                              SecondaryButton(
                                label: 'Оставить запрос менеджеру',
                                icon: Icons.support_agent_rounded,
                                fullWidth: true,
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
                        if (_hasValue(contact.routeLabel) ||
                            _hasValue(contact.parkingHint) ||
                            _hasValue(contact.arrivalHint)) ...[
                          const SizedBox(height: SKSpacing.x6),
                          Container(
                            padding: const EdgeInsets.all(SKSpacing.x4),
                            decoration: BoxDecoration(
                              color: c.elevated,
                              borderRadius: BorderRadius.circular(SKRadius.xl),
                              border: Border.all(color: c.hairline, width: 0.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Как добраться',
                                  style: textTheme.titleLarge,
                                ),
                                if (_hasValue(contact.routeLabel)) ...[
                                  const SizedBox(height: SKSpacing.x2),
                                  Text(
                                    contact.routeLabel,
                                    style: textTheme.labelMedium?.copyWith(
                                      color: c.cta,
                                    ),
                                  ),
                                ],
                                if (_hasValue(contact.parkingHint)) ...[
                                  const SizedBox(height: SKSpacing.x3),
                                  Text(
                                    contact.parkingHint!,
                                    style: textTheme.bodyLarge,
                                  ),
                                ],
                                if (_hasValue(contact.arrivalHint)) ...[
                                  const SizedBox(height: SKSpacing.x2),
                                  Text(
                                    contact.arrivalHint!,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (snapshot.data!.contentBlocks.isNotEmpty) ...[
                          const SizedBox(height: SKSpacing.x6),
                          const StarKidsSectionHeader(
                            title: 'Полезно знать перед визитом',
                          ),
                          const SizedBox(height: SKSpacing.x3),
                          ...snapshot.data!.contentBlocks.map(
                            (block) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: SKSpacing.x3,
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

class _WhatsAppButton extends StatefulWidget {
  const _WhatsAppButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_WhatsAppButton> createState() => _WhatsAppButtonState();
}

class _WhatsAppButtonState extends State<_WhatsAppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.965 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: widget.enabled ? 1 : 0.55,
        duration: const Duration(milliseconds: 160),
        child: Material(
          color: const Color(0xFF25D366),
          borderRadius: BorderRadius.circular(SKRadius.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(SKRadius.pill),
            onTap: widget.enabled ? widget.onTap : null,
            onTapDown:
                widget.enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            splashColor: Colors.white.withValues(alpha: 0.18),
            highlightColor: Colors.transparent,
            child: const SizedBox(
              height: 56,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 18),
                  SizedBox(width: SKSpacing.x2),
                  Text(
                    'Написать в WhatsApp',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Geist',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(SK.rLg),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE5E7EB), Color(0xFFD1D5DB)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _MapGridPainter()),
            ),
            Center(
              child: Transform.rotate(
                angle: -0.785398,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: SK.accent,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(SK.rPill),
                      topRight: Radius.circular(SK.rPill),
                      bottomLeft: Radius.circular(SK.rPill),
                    ),
                    boxShadow: SK.shadowMd,
                  ),
                  child: Transform.rotate(
                    angle: 0.785398,
                    child: const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height * 0.35, size.height), paint);
    }
    for (var y = 10.0; y < size.height; y += 28) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y - size.width * 0.12), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) => false;
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
    final c = SKTheme.of(context).colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: SKSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.cta),
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
              boxShadow: SKShadows.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: SKSpacing.x2),
                Text(description, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: SKSpacing.x4),
                SecondaryButton(
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
