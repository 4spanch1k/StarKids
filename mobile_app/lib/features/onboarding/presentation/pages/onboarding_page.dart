import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
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
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.branchSelection);
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
    );
  }
}
