import 'package:flutter/material.dart';

import '../../features/birthdays/presentation/pages/birthdays_page.dart';
import '../../features/branches/presentation/pages/branch_selection_page.dart';
import '../../features/branches/presentation/pages/branch_details_page.dart';
import '../../features/contacts/presentation/pages/contacts_map_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/menu/presentation/pages/menu_page.dart';
import '../../features/news/presentation/models/news_details_page_args.dart';
import '../../features/news/presentation/pages/news_details_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/promotions/presentation/pages/promotions_page.dart';
import '../../features/tickets/presentation/pages/tickets_page.dart';
import '../../features/request_history/presentation/pages/request_history_page.dart';
import '../../features/requests/presentation/models/request_page_args.dart';
import '../../features/requests/presentation/pages/request_page.dart';
import '../../core/design_system/widgets/star_kids_motion.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboarding:
        return _page(const OnboardingPage(), settings);
      case AppRoutes.branchSelection:
        return _page(const BranchSelectionPage(), settings);
      case AppRoutes.home:
        return _page(const HomePage(), settings);
      case AppRoutes.branchDetails:
        return _page(const BranchDetailsPage(), settings);
      case AppRoutes.birthdays:
        return _page(const BirthdaysPage(), settings);
      case AppRoutes.promotions:
        return _page(const PromotionsPage(), settings);
      case AppRoutes.tickets:
        return _page(const TicketsPage(), settings);
      case AppRoutes.menu:
        return _page(const MenuPage(), settings);
      case AppRoutes.contacts:
        return _page(const ContactsMapPage(), settings);
      case AppRoutes.requests:
        return _page(
          RequestPage(
            args: settings.arguments is RequestPageArgs
                ? settings.arguments as RequestPageArgs
                : null,
          ),
          settings,
        );
      case AppRoutes.notifications:
        return _page(const NotificationsPage(), settings);
      case AppRoutes.newsDetails:
        return _page(
          NewsDetailsPage(
            args: settings.arguments is NewsDetailsPageArgs
                ? settings.arguments as NewsDetailsPageArgs
                : null,
          ),
          settings,
        );
      case AppRoutes.profile:
        return _page(const ProfilePage(), settings);
      case AppRoutes.myRequests:
        return _page(const RequestHistoryPage(), settings);
      default:
        return _page(const HomePage(), settings);
    }
  }

  static Route<dynamic> _page(Widget page, RouteSettings settings) {
    return buildStarKidsPageRoute<dynamic>(page: page, settings: settings);
  }
}
