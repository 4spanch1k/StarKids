import '../../../core/api/api_client.dart';
import '../domain/public_content_block.dart';
import '../domain/public_content_repository.dart';
import '../domain/public_faq_item.dart';
import 'public_content_api_models.dart';

class ApiPublicContentRepository implements PublicContentRepository {
  ApiPublicContentRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<PublicContentBlock>> listContentBlocks({
    required String surface,
  }) async {
    try {
      final encodedSurface = Uri.encodeQueryComponent(surface);
      final response =
          await _apiClient.getJson('/content-blocks?surface=$encodedSurface');
      final jsonList = response.jsonListBody;

      if (!response.isSuccess || jsonList == null) {
        return const [];
      }

      return jsonList
          .whereType<Map<String, dynamic>>()
          .map(PublicContentBlockDto.fromJson)
          .map((item) => item.toDomain())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<PublicFaqItem>> listFaqs() async {
    try {
      final response = await _apiClient.getJson('/faqs');
      final jsonList = response.jsonListBody;

      if (!response.isSuccess || jsonList == null) {
        return const [];
      }

      return jsonList
          .whereType<Map<String, dynamic>>()
          .map(PublicFaqItemDto.fromJson)
          .map((item) => item.toDomain())
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
