import '../../../core/api/api_client.dart';
import '../domain/promotion_offer.dart';
import '../domain/promotion_repository.dart';
import 'promotion_api_models.dart';

class ApiPromotionRepository implements PromotionRepository {
  ApiPromotionRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<PromotionOffer>> listPromotions(String branchId) async {
    final response = await _apiClient.getJson(
      '/promotions?branch_id=${Uri.encodeQueryComponent(branchId)}',
    );
    final jsonList = response.jsonListBody;

    if (!response.isSuccess || jsonList == null) {
      throw StateError('Promotions are not available');
    }

    return jsonList
        .whereType<Map<String, dynamic>>()
        .map(PromotionOfferDto.fromJson)
        .map((item) => item.toDomain())
        .toList();
  }
}
