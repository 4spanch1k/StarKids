import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:star_kids_mobile/app/router/app_router.dart';
import 'package:star_kids_mobile/app/router/app_routes.dart';
import 'package:star_kids_mobile/features/tickets/presentation/models/ticket_detail_page_args.dart';
import 'package:star_kids_mobile/features/tickets/presentation/pages/ticket_detail_page.dart';

void main() {
  test('ticket detail deep-link route resolves a ticket id', () {
    final route = AppRouter.onGenerateRoute(RouteSettings(
      name: AppRoutes.ticketDetail,
      arguments: const TicketDetailPageArgs(ticketId: 'ticket-1'),
    ));

    expect(route.settings.name, AppRoutes.ticketDetail);
    expect((route as dynamic).builder, isNotNull);
  });
}
