import 'request_status.dart';
import 'request_type.dart';

class ContactRequestSubmission {
  const ContactRequestSubmission({
    required this.requestId,
    required this.type,
    required this.status,
  });

  final String requestId;
  final RequestType type;
  final RequestStatus status;
}
