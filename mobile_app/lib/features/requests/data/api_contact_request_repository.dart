import '../../../core/api/api_client.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/mobile_auth_authorization.dart';
import '../../auth/data/mobile_auth_session_storage.dart';
import '../domain/contact_request_payload.dart';
import '../domain/contact_request_repository.dart';
import '../domain/contact_request_submission.dart';
import 'contact_request_api_contract.dart';
import 'contact_request_api_models.dart';

class ApiContactRequestRepository implements ContactRequestRepository {
  ApiContactRequestRepository({
    required ApiClient apiClient,
    required MobileAuthSessionStorage sessionStorage,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage;

  final ApiClient _apiClient;
  final MobileAuthSessionStorage _sessionStorage;

  @override
  Future<Result<ContactRequestSubmission>> submitContactRequest(
    ContactRequestPayload payload,
  ) async {
    try {
      final session = await _sessionStorage.readSession();
      final response = await _apiClient.postJson(
        ContactRequestApiContract.endpoint,
        body: ContactRequestBodyDto.fromDomain(payload).toJson(),
        headers: session == null
            ? null
            : buildMobileAuthAuthorizationHeader(session),
      );

      if (response.isSuccess && response.jsonBody != null) {
        final submission = ContactRequestSuccessDto.fromJson(
          response.jsonBody!,
        ).toDomain();
        return Success<ContactRequestSubmission>(submission);
      }

      return const Failure<ContactRequestSubmission>(
        'Не удалось отправить запрос. Проверьте данные и попробуйте снова.',
      );
    } catch (_) {
      return const Failure<ContactRequestSubmission>(
        'Не удалось отправить запрос. Проверьте интернет и попробуйте снова.',
      );
    }
  }
}
