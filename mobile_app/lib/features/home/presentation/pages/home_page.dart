import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Star Kids')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Lean MVP shell',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'The home screen should prioritize birthdays, promotions, pricing, '
              'and fast contact actions.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            _HomeActionCard(
              title: 'Birthdays',
              description: 'Main monetization flow for the mobile MVP.',
              routeName: AppRoutes.birthdays,
            ),
            _HomeActionCard(
              title: 'Promotions',
              description: 'Retention and push-ready offer area.',
              routeName: AppRoutes.promotions,
            ),
            _HomeActionCard(
              title: 'Request form',
              description: 'Lead capture for contact, callback, and birthdays.',
              routeName: AppRoutes.requests,
            ),
            _HomeActionCard(
              title: 'Notifications',
              description: 'Push inbox and read state foundation.',
              routeName: AppRoutes.notifications,
            ),
            _HomeActionCard(
              title: 'Profile',
              description: 'Guest-to-auth transition will land here later.',
              routeName: AppRoutes.profile,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.title,
    required this.description,
    required this.routeName,
  });

  final String title;
  final String description;
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(20),
          title: Text(title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(description),
          ),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => Navigator.of(context).pushNamed(routeName),
        ),
      ),
    );
  }
}

