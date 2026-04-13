import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/foundations/star_kids_spacing.dart';
import '../../../../core/design_system/widgets/star_kids_brand_logo.dart';
import '../../../../core/design_system/widgets/star_kids_motion.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StarKidsReveal(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox.square(
                    dimension: 104,
                    child: StarKidsBrandLogo(logoSize: 92),
                  ),
                ),
                const SizedBox(height: StarKidsSpacing.xl),
                Text(
                  'Star Kids Shymkent',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Parent-first mobile MVP for branches, birthdays, promotions, '
                  'and quick requests.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushReplacementNamed(AppRoutes.branchSelection);
                  },
                  child: const Text('Continue'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Guest-friendly entry stays enabled for MVP.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
