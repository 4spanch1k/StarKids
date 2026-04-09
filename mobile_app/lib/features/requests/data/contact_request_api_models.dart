import '../domain/contact_request_payload.dart';
import '../domain/contact_request_submission.dart';
import '../domain/request_status.dart';
import '../domain/request_type.dart';
import 'contact_request_api_contract.dart';

class ContactRequestBodyDto {
  const ContactRequestBodyDto({
    required this.name,
    required this.phone,
    this.email,
    this.message,
  });

  final String name;
  final String phone;
  final String? email;
  final String? message;

  factory ContactRequestBodyDto.fromDomain(ContactRequestPayload payload) {
    return ContactRequestBodyDto(
      name: payload.name,
      phone: payload.phone,
      email: payload.email,
      message: payload.message,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ContactRequestApiContract.name: name,
      ContactRequestApiContract.phone: phone,
      if (email != null) ContactRequestApiContract.email: email,
      if (message != null) ContactRequestApiContract.message: message,
    };
  }
}

class ContactRequestSuccessDto {
  const ContactRequestSuccessDto({
    required this.id,
    required this.type,
    required this.status,
  });

  final String id;
  final String type;
  final String status;

  factory ContactRequestSuccessDto.fromJson(Map<String, dynamic> json) {
    return ContactRequestSuccessDto(
      id: json[ContactRequestApiContract.id] as String? ?? '',
      type: json[ContactRequestApiContract.type] as String? ?? '',
      status: json[ContactRequestApiContract.status] as String? ?? '',
    );
  }

  ContactRequestSubmission toDomain() {
    return ContactRequestSubmission(
      requestId: id,
      type: RequestType.fromApi(type),
      status: RequestStatus.fromApi(status),
    );
  }
}
