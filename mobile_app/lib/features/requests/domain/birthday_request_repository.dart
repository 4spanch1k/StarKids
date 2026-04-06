import '../../../core/utils/result.dart';
import 'birthday_request_payload.dart';
import 'birthday_request_submission.dart';

abstract interface class BirthdayRequestRepository {
  Future<Result<BirthdayRequestSubmission>> submitBirthdayRequest(
    BirthdayRequestPayload payload,
  );
}
