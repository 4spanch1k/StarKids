import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/features/promotions/data/fallback_promotion_repository.dart';
import 'package:star_kids_mobile/features/promotions/domain/promotion_offer.dart';
import 'package:star_kids_mobile/features/promotions/domain/promotion_repository.dart';

void main() {
  const liveOffer = PromotionOffer(
    id: 'live',
    title: 'Live offer',
    description: 'From API',
    badgeLabel: 'Live',
    imagePath: 'live.jpg',
    branchIds: [],
    ctaLabel: 'Open',
  );
  const demoOffer = PromotionOffer(
    id: 'demo',
    title: 'Demo offer',
    description: 'Fallback',
    badgeLabel: 'Demo',
    imagePath: 'demo.jpg',
    branchIds: [],
    ctaLabel: 'Open',
  );

  test('keeps non-empty API promotions', () async {
    const repository = FallbackPromotionRepository(
      primary: _PromotionRepository(items: [liveOffer]),
      fallback: _PromotionRepository(items: [demoOffer]),
    );

    final result = await repository.listPromotions('branch');

    expect(result, const [liveOffer]);
  });

  test('uses demo promotions when API is empty', () async {
    const repository = FallbackPromotionRepository(
      primary: _PromotionRepository(items: []),
      fallback: _PromotionRepository(items: [demoOffer]),
    );

    final result = await repository.listPromotions('branch');

    expect(result, const [demoOffer]);
  });
}

class _PromotionRepository implements PromotionRepository {
  const _PromotionRepository({required this.items});

  final List<PromotionOffer> items;

  @override
  Future<List<PromotionOffer>> listPromotions(String branchId) async => items;
}
