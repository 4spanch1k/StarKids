import '../../../birthdays/domain/birthday_package.dart';
import '../../domain/request_type.dart';

class RequestPageArgs {
  const RequestPageArgs({
    this.initialType = RequestType.birthdayRequest,
    this.initialPackageId,
    this.initialPackage,
  });

  final RequestType initialType;
  final String? initialPackageId;
  final BirthdayPackage? initialPackage;
}
