import '../../../app/router/app_routes.dart';
import '../../../features/news/presentation/models/news_details_page_args.dart';
import '../../../features/promotions/presentation/models/promotion_detail_page_args.dart';
import '../../../features/tickets/presentation/models/ticket_detail_page_args.dart';

enum NotificationDestinationType {
  home,
  tickets,
  birthdays,
  promotions,
  profile,
  ticketDetail,
  birthday,
  promotionDetail,
  newsDetail
}

class NotificationDestination {
  const NotificationDestination({required this.type, this.entityId});

  final NotificationDestinationType type;
  final String? entityId;

  String get routeName {
    switch (type) {
      case NotificationDestinationType.ticketDetail:
        return AppRoutes.ticketDetail;
      case NotificationDestinationType.home:
        return AppRoutes.home;
      case NotificationDestinationType.tickets:
        return AppRoutes.tickets;
      case NotificationDestinationType.birthdays:
        return AppRoutes.birthdays;
      case NotificationDestinationType.promotions:
        return AppRoutes.promotions;
      case NotificationDestinationType.profile:
        return AppRoutes.profile;
      case NotificationDestinationType.birthday:
        return AppRoutes.birthdays;
      case NotificationDestinationType.promotionDetail:
        return AppRoutes.promotionDetail;
      case NotificationDestinationType.newsDetail:
        return AppRoutes.newsDetails;
    }
  }

  Object? get arguments {
    final id = entityId?.trim() ?? '';
    switch (type) {
      case NotificationDestinationType.home:
      case NotificationDestinationType.tickets:
      case NotificationDestinationType.birthdays:
      case NotificationDestinationType.promotions:
      case NotificationDestinationType.profile:
        return null;
      case NotificationDestinationType.ticketDetail:
        return id.isEmpty ? null : TicketDetailPageArgs(ticketId: id);
      case NotificationDestinationType.newsDetail:
        return id.isEmpty ? null : NewsDetailsPageArgs(newsId: id);
      case NotificationDestinationType.birthday:
        return null;
      case NotificationDestinationType.promotionDetail:
        return id.isEmpty ? null : PromotionDetailPageArgs(promotionId: id);
    }
  }

  static NotificationDestination? fromPayload(Map<String, dynamic> payload) {
    final rawType = (payload['destination_type'] ??
            payload['destinationType'] ??
            payload['destination'] ??
            payload['type'])
        ?.toString()
        .trim()
        .toLowerCase();
    final id = (payload['destination_id'] ??
            payload['destinationId'] ??
            payload['entity_id'] ??
            payload['entityId'] ??
            payload['news_id'] ??
            payload['newsId'])
        ?.toString();
    switch (rawType) {
      case 'home':
        return const NotificationDestination(type: NotificationDestinationType.home);
      case 'tickets':
        return const NotificationDestination(type: NotificationDestinationType.tickets);
      case 'birthdays':
      case 'birthday':
        return const NotificationDestination(type: NotificationDestinationType.birthdays);
      case 'promotions':
        return const NotificationDestination(type: NotificationDestinationType.promotions);
      case 'profile':
        return const NotificationDestination(type: NotificationDestinationType.profile);
      case 'ticket_detail':
      case 'ticket':
        return id?.trim().isNotEmpty ?? false
            ? NotificationDestination(
                type: NotificationDestinationType.ticketDetail, entityId: id)
            : null;
      case 'birthday_detail':
        return const NotificationDestination(
            type: NotificationDestinationType.birthday);
      case 'promotion_detail':
      case 'promotion':
      case 'promo':
        return id?.trim().isNotEmpty ?? false
            ? NotificationDestination(
                type: NotificationDestinationType.promotionDetail, entityId: id)
            : null;
      case 'news':
      case 'news_detail':
        return id?.trim().isNotEmpty ?? false
            ? NotificationDestination(
                type: NotificationDestinationType.newsDetail, entityId: id)
            : null;
      default:
        return const NotificationDestination(type: NotificationDestinationType.home);
    }
  }
}
