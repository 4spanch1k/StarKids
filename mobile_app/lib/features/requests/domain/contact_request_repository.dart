import '../../../core/utils/result.dart';
import 'contact_request_payload.dart';
import 'contact_request_submission.dart';

abstract interface class ContactRequestRepository {
  Future<Result<ContactRequestSubmission>> submitContactRequest(
    ContactRequestPayload payload,
  );
}
