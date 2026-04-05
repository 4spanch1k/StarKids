import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../data/branch_seed_data.dart';

class BranchSelectionPage extends StatelessWidget {
  const BranchSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a branch')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start with the branch that will drive prices, contacts, and promotions.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: branchSeedData.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final branch = branchSeedData[index];

                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),
                        title: Text(branch.name),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(branch.address),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.of(context).pushReplacementNamed(
                            AppRoutes.home,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

