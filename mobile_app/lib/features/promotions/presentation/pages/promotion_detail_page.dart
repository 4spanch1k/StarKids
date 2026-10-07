import 'package:flutter/material.dart';

import '../../../../app/di/service_registry.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/widgets/glass_app_bar.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../../core/design_system/widgets/star_kids_media_image.dart';
import '../../../../core/design_system/widgets/stable_future_builder.dart';
import '../../../requests/domain/request_type.dart';
import '../../../requests/presentation/models/request_page_args.dart';
import '../../domain/promotion_offer.dart';
import '../models/promotion_detail_page_args.dart';

class PromotionDetailPage extends StatelessWidget {
  const PromotionDetailPage({super.key, required this.args});

  final PromotionDetailPageArgs args;

  @override
  Widget build(BuildContext context) {
    final branch = ServiceRegistry.selectedBranchController.selectedBranch;
    return Scaffold(
      appBar: const GlassAppBar(title: Text('Акция')),
      body: StableFutureBuilder<PromotionOffer?>(
        cacheKey: '${branch.id}:${args.promotionId}',
        futureFactory: () async {
          final offers = await ServiceRegistry.promotionRepository
              .listPromotions(branch.id);
          for (final offer in offers) {
            if (offer.id == args.promotionId) return offer;
          }
          return null;
        },
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final offer = snapshot.data;
          if (offer == null) {
            return const Center(child: Text('Акция больше недоступна.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                SKSpacing.x5, SKSpacing.x2, SKSpacing.x5, SKSpacing.x6),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(SKRadius.xl),
                child: AspectRatio(
                    aspectRatio: 19 / 10,
                    child: StarKidsMediaImage(
                        source: offer.imagePath,
                        fallbackSource: 'assets/images/promo_hero.jpg')),
              ),
              const SizedBox(height: SKSpacing.x5),
              Text(offer.badgeLabel,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: SKSpacing.x2),
              Text(offer.title,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: SKSpacing.x3),
              Text(offer.description,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: SKSpacing.x5),
              PrimaryButton(
                label: offer.ctaLabel,
                onPressed: () => Navigator.of(context).pushNamed(
                  AppRoutes.requests,
                  arguments: const RequestPageArgs(
                      initialType: RequestType.birthdayRequest),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
