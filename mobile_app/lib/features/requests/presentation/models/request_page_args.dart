import '../../../birthdays/domain/birthday_package.dart';

class RequestPageArgs {
  const RequestPageArgs({
    this.initialPackageId,
    this.initialPackage,
  });

  final String? initialPackageId;
  final BirthdayPackage? initialPackage;
}
