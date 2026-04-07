import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_colors.dart';
import '../../../../core/design_system/foundations/star_kids_radii.dart';
import '../../../../core/design_system/foundations/star_kids_shadows.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_bottom_cta_bar.dart';
import '../../../../core/design_system/widgets/star_kids_button.dart';
import '../../../../core/design_system/widgets/star_kids_section_header.dart';
import '../../data/seed_prices_rules_repository.dart';
import '../../domain/branch_prices_rules.dart';

class PricesRulesPage extends StatelessWidget {
  const PricesRulesPage({super.key});

  static const SeedPricesRulesRepository _repository =
      SeedPricesRulesRepository();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServiceRegistry.selectedBranchController,
      builder: (context, _) {
        final branch = ServiceRegistry.selectedBranchController.selectedBranch;

        return Scaffold(
          appBar: AppBar(title: const Text('Цены и правила')),
          bottomNavigationBar: StarKidsBottomCtaBar(
            child: StarKidsButton.primary(
              label: 'Посмотреть пакеты праздника',
              icon: Icons.cake_rounded,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.birthdays),
            ),
          ),
          body: FutureBuilder<BranchPricesRules>(
            future: _repository.getForBranch(branch.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return const _PricesRulesStateView(
                  title: 'Цены пока недоступны',
                  description:
                      'Экран готов, но тарифы и правила для этого филиала пока не удалось показать.',
                );
              }

              final data = snapshot.data!;
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
                        Text(data.introTitle, style: textTheme.headlineMedium),
                        const SizedBox(height: StarKidsSpacing.md),
                        Text(data.introDescription, style: textTheme.bodyLarge),
                      ],
                    ),
                  ),
                  const SizedBox(height: StarKidsSpacing.x2l),
                  const StarKidsSectionHeader(
                    title: 'Тарифы посещения',
                    description:
                        'Компактный экран вместо тяжелой таблицы. Достаточно, чтобы быстро понять базовый бюджет.',
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  ...data.visitTariffs.map(
                    (tariff) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: StarKidsSpacing.md),
                      child: _TariffCard(tariff: tariff),
                    ),
                  ),
                  const SizedBox(height: StarKidsSpacing.x2l),
                  const StarKidsSectionHeader(
                    title: 'Что важно знать перед визитом',
                    description:
                        'Правила собраны коротко и без мелкого текста, чтобы не ломать коммерческий flow.',
                  ),
                  const SizedBox(height: StarKidsSpacing.md),
                  ...data.rules.map(
                    (rule) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: StarKidsSpacing.md),
                      child: _RuleRow(rule: rule),
                    ),
                  ),
                  const SizedBox(height: StarKidsSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(StarKidsSpacing.lg),
                    decoration: BoxDecoration(
                      color: StarKidsColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Для дня рождения', style: textTheme.titleLarge),
                        const SizedBox(height: StarKidsSpacing.sm),
                        Text(data.birthdayNote, style: textTheme.bodyLarge),
                      ],
                    ),
                  ),
                  if (data.disclaimer != null) ...[
                    const SizedBox(height: StarKidsSpacing.lg),
                    Text(
                      data.disclaimer!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: StarKidsColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _TariffCard extends StatelessWidget {
  const _TariffCard({
    required this.tariff,
  });

  final VisitTariff tariff;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(StarKidsSpacing.lg),
      decoration: BoxDecoration(
        color: StarKidsColors.surfacePrimary,
        borderRadius: BorderRadius.circular(StarKidsRadii.xl),
        border: Border.all(color: StarKidsColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(tariff.title, style: textTheme.titleLarge)),
              const SizedBox(width: StarKidsSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: StarKidsSpacing.md,
                  vertical: StarKidsSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: StarKidsColors.brandHighlight,
                  borderRadius: BorderRadius.circular(StarKidsRadii.full),
                ),
                child: Text(
                  tariff.priceLabel,
                  style: textTheme.labelMedium?.copyWith(
                    color: StarKidsColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: StarKidsSpacing.sm),
          Text(tariff.description, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.rule,
  });

  final String rule;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: StarKidsColors.brandSecondary,
          ),
        ),
        const SizedBox(width: StarKidsSpacing.sm),
        Expanded(
          child: Text(
            rule,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _PricesRulesStateView extends StatelessWidget {
  const _PricesRulesStateView({
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
