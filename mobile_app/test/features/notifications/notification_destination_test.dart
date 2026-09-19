import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/app/router/app_routes.dart';
import 'package:star_kids_mobile/features/notifications/domain/notification_destination.dart';

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
}
