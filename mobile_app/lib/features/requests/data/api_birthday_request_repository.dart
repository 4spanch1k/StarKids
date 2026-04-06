import '../../../core/api/api_client.dart';
import '../../../core/utils/result.dart';
import '../domain/birthday_request_payload.dart';
import '../domain/birthday_request_repository.dart';
import '../domain/birthday_request_submission.dart';
import 'birthday_request_api_contract.dart';
import 'birthday_request_api_models.dart';

class ApiBirthdayRequestRepository implements BirthdayRequestRepository {
  ApiBirthdayRequestRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<BirthdayRequestSubmission>> submitBirthdayRequest(
    BirthdayRequestPayload payload,
  ) async {
    try {
      final response = await _apiClient.postJson(
        BirthdayRequestApiContract.endpoint,
        body: BirthdayRequestBodyDto.fromDomain(payload).toJson(),
      );

      if (response.isSuccess && response.jsonBody != null) {
        final submission = BirthdayRequestSuccessDto.fromJson(
          response.jsonBody!,
        ).toDomain();
        return Success<BirthdayRequestSubmission>(submission);
      }

      final error = BirthdayRequestApiError.fromJson(response.jsonBody);
      return Failure<BirthdayRequestSubmission>(error.userMessage);
    } catch (_) {
      return const Failure<BirthdayRequestSubmission>(
        'Не удалось отправить заявку. Проверьте интернет и попробуйте снова.',
      );
    }
  }
}
