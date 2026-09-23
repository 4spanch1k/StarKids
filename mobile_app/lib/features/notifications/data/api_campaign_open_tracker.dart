import '../../../core/api/api_client.dart';
import '../../auth/data/mobile_auth_session_storage.dart';

/// Best-effort authenticated campaign-open tracking.
///
/// Tracking is intentionally independent from navigation: an unavailable
/// network must never prevent the user from opening the destination.
class ApiCampaignOpenTracker {
  ApiCampaignOpenTracker({
    required ApiClient apiClient,
    required MobileAuthSessionStorage sessionStorage,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage;

  final ApiClient _apiClient;
  final MobileAuthSessionStorage _sessionStorage;

  Future<void> track(String campaignId) async {
    final id = campaignId.trim();
    if (id.isEmpty) return;
    try {
      final session = await _sessionStorage.readSession();
      final accessToken = session?.accessToken.trim();
      if (accessToken == null || accessToken.isEmpty) return;
      await _apiClient.postJson(
        '/push-campaigns/$id/open',
        body: const <String, dynamic>{},
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    } catch (_) {
      // Attribution is best effort; navigation remains the primary action.
    }
  }
}
