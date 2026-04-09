import '../../../birthdays/domain/birthday_package.dart';
import '../../domain/request_type.dart';

class RequestPageArgs {
  const RequestPageArgs({
    this.initialType = RequestType.birthdayRequest,
    this.initialPackageId,
    this.initialPackage,
    this.initialContactContextLabel,
    this.initialContactMessage,
  });

  final RequestType initialType;
  final String? initialPackageId;
  final BirthdayPackage? initialPackage;
  final String? initialContactContextLabel;
  final String? initialContactMessage;
}
