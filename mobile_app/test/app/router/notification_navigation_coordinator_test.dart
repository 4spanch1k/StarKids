import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/app/router/app_routes.dart';
import 'package:star_kids_mobile/app/router/notification_navigation_coordinator.dart';

void main() {
  final coordinator = NotificationNavigationCoordinator.instance;

  tearDown(() => coordinator.resetForTesting());

  testWidgets('queues a cold-start destination until authentication is ready',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const SizedBox.shrink(),
        onGenerateRoute: (settings) {
          destination = settings.name;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox.shrink(),
          );
        },
      ),
    );

    coordinator.attach(
      navigator: navigatorKey.currentState!,
      authenticated: false,
    );
    coordinator.handlePayload({
      'destination_type': 'ticket_detail',
      'destination_id': 'ticket-1',
    });
    await tester.pump();
    expect(destination, isNull);

    coordinator.attach(
      navigator: navigatorKey.currentState!,
      authenticated: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(destination, AppRoutes.ticketDetail);
  });

  testWidgets('routes a warm ticket notification through the same coordinator',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const SizedBox.shrink(),
        onGenerateRoute: (settings) {
          destination = settings.name;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox.shrink(),
          );
        },
      ),
    );

    coordinator.attach(
      navigator: navigatorKey.currentState!,
      authenticated: true,
    );
    coordinator.handlePayload({
      'destination_type': 'ticket_detail',
      'destination_id': 'ticket-2',
    });
    await tester.pumpAndSettle();
    expect(destination, AppRoutes.ticketDetail);
  });

  testWidgets('foreground message is visible and routes through the action',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        home: const Scaffold(body: SizedBox.shrink()),
        onGenerateRoute: (settings) {
          destination = settings.name;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: SizedBox.shrink()),
          );
        },
      ),
    );

    coordinator.attach(
      navigator: navigatorKey.currentState!,
      authenticated: true,
      scaffoldMessenger: messengerKey.currentState,
    );
    coordinator.showForegroundMessage(
      title: 'Событие',
      body: 'Откройте праздники',
      payload: const {'destination_type': 'birthdays'},
    );
    await tester.pump();

    expect(find.text('Событие'), findsOneWidget);
    expect(find.text('Открыть'), findsOneWidget);

    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pumpAndSettle();
    expect(destination, AppRoutes.birthdays);
  });

  testWidgets('foreground message with unknown destination falls back home',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        home: const Scaffold(body: SizedBox.shrink()),
        onGenerateRoute: (settings) {
          destination = settings.name;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: SizedBox.shrink()),
          );
        },
      ),
    );

    coordinator.attach(
      navigator: navigatorKey.currentState!,
      authenticated: true,
      scaffoldMessenger: messengerKey.currentState,
    );
    coordinator.showForegroundMessage(
      title: 'Уведомление',
      body: null,
      payload: const {'destination_type': 'unsupported'},
    );
    await tester.pump();
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pumpAndSettle();

    expect(destination, AppRoutes.home);
  });

  testWidgets('tracks a campaign only after the foreground action',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    var tracked = <String>[];
    String? destination;
    coordinator.configureCampaignOpenTracker((campaignId) async {
      tracked.add(campaignId);
    });
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        home: const Scaffold(body: SizedBox.shrink()),
        onGenerateRoute: (settings) {
          destination = settings.name;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: SizedBox.shrink()),
          );
        },
      ),
    );
    coordinator.attach(
      navigator: navigatorKey.currentState!,
      authenticated: true,
      scaffoldMessenger: messengerKey.currentState,
    );
    coordinator.showForegroundMessage(
      title: 'Кампания',
      body: 'Откройте',
      payload: const {
        'type': 'campaign',
        'campaignId': 'campaign-1',
        'destination': 'birthdays',
      },
    );
    await tester.pump();
    expect(tracked, isEmpty);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pumpAndSettle();
    expect(tracked, ['campaign-1']);
    expect(destination, AppRoutes.birthdays);
  });

  testWidgets('keeps campaign attribution pending until auth is ready',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final tracked = <String>[];
    coordinator.configureCampaignOpenTracker((campaignId) async {
      tracked.add(campaignId);
    });
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const SizedBox.shrink(),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
    coordinator.attach(
      navigator: navigatorKey.currentState!,
      authenticated: false,
    );
    coordinator.handlePayload(const {
      'type': 'campaign',
      'campaignId': 'campaign-2',
      'destination': 'home',
    });
    await tester.pump();
    expect(tracked, isEmpty);
    coordinator.attach(
      navigator: navigatorKey.currentState!,
      authenticated: true,
    );
    await tester.pumpAndSettle();
    expect(tracked, ['campaign-2']);
  });
}
