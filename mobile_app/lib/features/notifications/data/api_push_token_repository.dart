import '../../../core/api/api_client.dart';
import '../domain/push_token_repository.dart';

/// Registers/removes FCM tokens by calling:
/// - PUT  /me/notification-device
/// - DELETE /me/notification-device
class ApiPushTokenRepository implements PushTokenRepository {
  ApiPushTokenRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<bool> registerToken({
    required String token,
    required String platform,
    required String permissionStatus,
    required String accessToken,
  }) async {
    try {
      final response = await _apiClient.putJson(
        '/me/notification-device',
        body: {
          'push_token': token,
          'platform': platform,
          'permission_status': permissionStatus,
          'notifications_enabled': true,
        },
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return response.isSuccess;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> removeToken({required String accessToken}) async {
    try {
      await _apiClient.deleteJson(
        '/me/notification-device',
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    } catch (_) {
      // Best-effort: ignore errors on token removal.
    }
  }
}
