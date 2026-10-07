import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/app/router/app_routes.dart';
import 'package:star_kids_mobile/features/notifications/domain/notification_destination.dart';
import 'package:star_kids_mobile/features/requests/presentation/models/request_page_args.dart';

void main() {
  test('maps ticket notification to typed ticket route', () {
    final destination = NotificationDestination.fromPayload({
      'destination_type': 'ticket_detail',
      'destination_id': 'ticket-1',
    });
    expect(destination?.type, NotificationDestinationType.ticketDetail);
    expect(destination?.routeName, AppRoutes.ticketDetail);
  });

  test(
      'maps birthday and promotion destinations without arbitrary route strings',
      () {
    final birthday =
        NotificationDestination.fromPayload({'destination_type': 'birthday'});
    final promotion = NotificationDestination.fromPayload({
      'destination_type': 'promotion_detail',
      'destination_id': 'promo-1',
    });
    expect(birthday?.routeName, AppRoutes.birthdays);
    expect(promotion?.routeName, AppRoutes.promotionDetail);
  });

  test('falls back to home for an unknown campaign destination', () {
    final destination = NotificationDestination.fromPayload({
      'type': 'campaign',
      'destination': 'future_event',
    });
    expect(destination?.type, NotificationDestinationType.home);
    expect(destination?.routeName, AppRoutes.home);
  });

  test('reduces foreground payload to an allowlisted destination', () {
    final destination = NotificationDestination.fromPayload({
      'destination_type': 'birthdays',
      'campaignId': 'campaign-1',
      'childName': 'private-name',
      'birthDate': '2020-01-01',
    });

    expect(destination?.toPayload(), {
      'destination_type': 'birthdays',
    });
  });

  test('preserves validated birthday context for request prefill', () {
    final destination = NotificationDestination.fromPayload({
      'destination_type': 'birthdays',
      'campaignId': 'campaign-1',
      'birthdayCycleId': 'cycle-1',
      'birthdayChildId': 'child-1',
      'preferredDate': '2026-10-06',
    });
    final args = destination?.arguments as RequestPageArgs;
    expect(args.sourceCampaignId, 'campaign-1');
    expect(args.birthdayCycleId, 'cycle-1');
    expect(args.initialChildId, 'child-1');
    expect(args.initialPreferredDate, DateTime(2026, 10, 6));
  });
}
