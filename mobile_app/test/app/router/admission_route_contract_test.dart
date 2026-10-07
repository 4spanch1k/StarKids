import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:star_kids_mobile/app/router/app_router.dart';
import 'package:star_kids_mobile/app/router/app_routes.dart';
import 'package:star_kids_mobile/features/promotions/presentation/models/promotion_detail_page_args.dart';
import 'package:star_kids_mobile/features/tickets/presentation/models/ticket_detail_page_args.dart';

void main() {
  test('ticket detail deep-link route resolves a ticket id', () {
    final route = AppRouter.onGenerateRoute(const RouteSettings(
      name: AppRoutes.ticketDetail,
      arguments: TicketDetailPageArgs(ticketId: 'ticket-1'),
    ));

    expect(route.settings.name, AppRoutes.ticketDetail);
    expect((route as dynamic).builder, isNotNull);
  });

  test('birthday and promotion destinations resolve to existing routes', () {
    final birthday = AppRouter.onGenerateRoute(
      const RouteSettings(name: AppRoutes.birthdays),
    );
    final promotion = AppRouter.onGenerateRoute(
      const RouteSettings(
        name: AppRoutes.promotionDetail,
        arguments: PromotionDetailPageArgs(promotionId: 'promo-1'),
      ),
    );

    expect(birthday.settings.name, AppRoutes.birthdays);
    expect(promotion.settings.name, AppRoutes.promotionDetail);
  });
}
