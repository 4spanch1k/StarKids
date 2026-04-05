import '../../core/api/api_client.dart';
import '../../core/storage/local_storage.dart';
import '../config/app_environment.dart';

abstract final class ServiceRegistry {
  static final apiClient = ApiClient(baseUrl: AppEnvironment.apiBaseUrl);
  static final localStorage = LocalStorage();
}

