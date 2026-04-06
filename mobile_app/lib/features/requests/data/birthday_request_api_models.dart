import '../domain/birthday_request_payload.dart';
import '../domain/birthday_request_submission.dart';
import 'birthday_request_api_contract.dart';

class BirthdayRequestBodyDto {
  const BirthdayRequestBodyDto({
    required this.branchId,
    required this.packageId,
    required this.name,
    required this.phone,
    required this.preferredDate,
    required this.guestCount,
    required this.comment,
  });

  final String branchId;
  final String? packageId;
  final String name;
  final String phone;
  final String preferredDate;
  final int guestCount;
  final String? comment;

  factory BirthdayRequestBodyDto.fromDomain(BirthdayRequestPayload payload) {
    return BirthdayRequestBodyDto(
      branchId: payload.branchId,
      packageId: payload.packageId,
      name: payload.name,
      phone: payload.phone,
      preferredDate: _formatDate(payload.preferredDate),
      guestCount: payload.guestCount,
      comment: payload.comment,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      BirthdayRequestApiContract.branchId: branchId,
      BirthdayRequestApiContract.packageId: packageId,
      BirthdayRequestApiContract.name: name,
      BirthdayRequestApiContract.phone: phone,
      BirthdayRequestApiContract.preferredDate: preferredDate,
      BirthdayRequestApiContract.guestCount: guestCount,
      BirthdayRequestApiContract.comment: comment,
    };
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class BirthdayRequestSuccessDto {
  const BirthdayRequestSuccessDto({
    required this.requestId,
    required this.submittedAt,
    required this.nextStep,
  });

  final String requestId;
  final DateTime submittedAt;
  final String nextStep;

  factory BirthdayRequestSuccessDto.fromJson(Map<String, dynamic> json) {
    return BirthdayRequestSuccessDto(
      requestId: json[BirthdayRequestApiContract.requestId] as String,
      submittedAt: DateTime.parse(
        json[BirthdayRequestApiContract.submittedAt] as String,
      ),
      nextStep: json[BirthdayRequestApiContract.nextStep] as String,
    );
  }

  BirthdayRequestSubmission toDomain() {
    return BirthdayRequestSubmission(
      requestId: requestId,
      submittedAt: submittedAt,
      nextStep: nextStep,
    );
  }
}

class BirthdayRequestApiError {
  const BirthdayRequestApiError({
    required this.message,
    required this.fieldErrors,
  });

  final String message;
  final Map<String, List<String>> fieldErrors;

  factory BirthdayRequestApiError.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const BirthdayRequestApiError(
        message: 'Не удалось отправить заявку. Попробуйте еще раз.',
        fieldErrors: {},
      );
    }

    final rawErrors = json[BirthdayRequestApiContract.errors];
    final fieldErrors = <String, List<String>>{};

    if (rawErrors is Map<String, dynamic>) {
      for (final entry in rawErrors.entries) {
        final value = entry.value;
        if (value is List) {
          fieldErrors[entry.key] = value.map((item) => '$item').toList();
        }
      }
    }

    return BirthdayRequestApiError(
      message: (json[BirthdayRequestApiContract.message] as String?) ??
          'Не удалось отправить заявку. Попробуйте еще раз.',
      fieldErrors: fieldErrors,
    );
  }

  String get userMessage {
    for (final errors in fieldErrors.values) {
      if (errors.isNotEmpty) {
        return errors.first;
      }
    }

    return message;
  }
}
