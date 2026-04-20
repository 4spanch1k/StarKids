import '../../../core/api/api_client.dart';
import '../domain/news_item.dart';
import '../domain/news_repository.dart';
import 'news_api_models.dart';

class ApiNewsRepository implements NewsRepository {
  ApiNewsRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<NewsItem>> listNews() async {
    final response = await _apiClient.getJson('/news');
    final jsonList = response.jsonListBody;

    if (!response.isSuccess || jsonList == null) {
      throw StateError('News feed is not available');
    }

    return jsonList
        .whereType<Map<String, dynamic>>()
        .map(NewsItemDto.fromJson)
        .map((item) => item.toDomain())
        .toList();
  }
}
