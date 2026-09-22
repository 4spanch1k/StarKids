import '../../../app/router/app_routes.dart';
import '../../../features/news/presentation/models/news_details_page_args.dart';
import '../../../features/promotions/presentation/models/promotion_detail_page_args.dart';
import '../../../features/tickets/presentation/models/ticket_detail_page_args.dart';
import '../../../features/requests/presentation/models/request_page_args.dart';

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
  const NotificationDestination(
      {required this.type,
      this.entityId,
      this.birthdayCycleId,
      this.childId,
      this.preferredDate,
      this.campaignId});

  final NotificationDestinationType type;
  final String? entityId;
  final String? birthdayCycleId;
  final String? childId;
  final DateTime? preferredDate;
  final String? campaignId;

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
      case NotificationDestinationType.promotions:
      case NotificationDestinationType.profile:
        return null;
      case NotificationDestinationType.birthdays:
        if (birthdayCycleId != null ||
            childId != null ||
            preferredDate != null) {
          return RequestPageArgs(
              initialChildId: childId,
              initialPreferredDate: preferredDate,
              sourceCampaignId: campaignId,
              birthdayCycleId: birthdayCycleId);
        }
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

  /// Returns the minimal, allowlisted payload safe to keep in a local
  /// notification action. Provider data such as phone numbers or child data
  /// is intentionally discarded.
  Map<String, String> toPayload() {
    final payload = <String, String>{'destination_type': _canonicalType};
    final id = entityId?.trim();
    if (id != null && id.isNotEmpty) {
      payload['destination_id'] = id;
    }
    if (birthdayCycleId != null) payload['birthdayCycleId'] = birthdayCycleId!;
    if (childId != null) payload['birthdayChildId'] = childId!;
    if (preferredDate != null) {
      payload['preferredDate'] =
          '${preferredDate!.year.toString().padLeft(4, '0')}-${preferredDate!.month.toString().padLeft(2, '0')}-${preferredDate!.day.toString().padLeft(2, '0')}';
    }
    if (birthdayCycleId != null && campaignId != null) {
      payload['campaignId'] = campaignId!;
    }
    return payload;
  }

  String get _canonicalType {
    return switch (type) {
      NotificationDestinationType.home => 'home',
      NotificationDestinationType.tickets => 'tickets',
      NotificationDestinationType.birthdays => 'birthdays',
      NotificationDestinationType.promotions => 'promotions',
      NotificationDestinationType.profile => 'profile',
      NotificationDestinationType.ticketDetail => 'ticket_detail',
      NotificationDestinationType.birthday => 'birthday',
      NotificationDestinationType.promotionDetail => 'promotion_detail',
      NotificationDestinationType.newsDetail => 'news_detail',
    };
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
    final birthdayCycleId = payload['birthdayCycleId']?.toString();
    final childId = payload['birthdayChildId']?.toString();
    final campaignId = payload['campaignId']?.toString();
    DateTime? preferredDate;
    final rawPreferredDate = payload['preferredDate']?.toString();
    if (rawPreferredDate != null) {
      preferredDate = DateTime.tryParse(rawPreferredDate);
    }
    switch (rawType) {
      case 'home':
        return const NotificationDestination(
            type: NotificationDestinationType.home);
      case 'tickets':
        return const NotificationDestination(
            type: NotificationDestinationType.tickets);
      case 'birthdays':
      case 'birthday':
        return NotificationDestination(
            type: NotificationDestinationType.birthdays,
            birthdayCycleId: birthdayCycleId,
            childId: childId,
            preferredDate: preferredDate,
            campaignId: campaignId);
      case 'promotions':
        return const NotificationDestination(
            type: NotificationDestinationType.promotions);
      case 'profile':
        return const NotificationDestination(
            type: NotificationDestinationType.profile);
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
        return const NotificationDestination(
            type: NotificationDestinationType.home);
    }
  }
}
