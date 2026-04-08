import '../domain/promotion_offer.dart';
import '../domain/promotion_repository.dart';
import 'promotion_seed_data.dart';

class SeedPromotionRepository implements PromotionRepository {
  const SeedPromotionRepository();

  @override
  Future<List<PromotionOffer>> listPromotions(String branchId) async {
    return promotionSeedData.where((promotion) {
      return promotion.branchIds.isEmpty ||
          promotion.branchIds.contains(branchId);
    }).toList();
  }
}
