import 'promotion_offer.dart';

abstract interface class PromotionRepository {
  Future<List<PromotionOffer>> listPromotions(String branchId);
}
