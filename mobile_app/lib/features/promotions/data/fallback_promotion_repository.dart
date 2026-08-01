import '../domain/promotion_offer.dart';
import '../domain/promotion_repository.dart';

class FallbackPromotionRepository implements PromotionRepository {
  const FallbackPromotionRepository({
    required PromotionRepository primary,
    required PromotionRepository fallback,
  })  : _primary = primary,
        _fallback = fallback;

  final PromotionRepository _primary;
  final PromotionRepository _fallback;

  @override
  Future<List<PromotionOffer>> listPromotions(String branchId) async {
    try {
      final promotions = await _primary.listPromotions(branchId);
      if (promotions.isNotEmpty) {
        return promotions;
      }
    } catch (_) {
      // Demo content keeps the experimental build useful without a populated API.
    }
    return _fallback.listPromotions(branchId);
  }
}
