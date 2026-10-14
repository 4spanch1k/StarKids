import '../../../birthdays/domain/birthday_package.dart';
import '../../domain/request_type.dart';

class RequestPageArgs {
  const RequestPageArgs({
    this.initialType = RequestType.birthdayRequest,
    this.initialPackageId,
    this.initialPackage,
    this.initialContactContextLabel,
    this.initialContactMessage,
    this.initialChildId,
    this.initialPreferredDate,
    this.sourceCampaignId,
    this.birthdayCycleId,
  });

  final RequestType initialType;
  final String? initialPackageId;
  final BirthdayPackage? initialPackage;
  final String? initialContactContextLabel;
  final String? initialContactMessage;
  final String? initialChildId;
  final DateTime? initialPreferredDate;
  final String? sourceCampaignId;
  final String? birthdayCycleId;
}
