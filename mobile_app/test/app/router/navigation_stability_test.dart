import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/app/router/app_router.dart';
import 'package:star_kids_mobile/app/router/app_routes.dart';
import 'package:star_kids_mobile/app/router/nested_navigation.dart';

void main() {
  testWidgets('nested back pops when history exists', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(leading: const NestedBackButton()),
                  body: const Text('Nested'),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NestedBackButton));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Nested'), findsNothing);
  });

  testWidgets('nested back falls home when route has no history',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/nested',
        routes: {
          AppRoutes.home: (_) => const Scaffold(body: Text('Home fallback')),
          '/nested': (_) => Scaffold(
                appBar: AppBar(leading: const NestedBackButton()),
                body: const Text('Nested'),
              ),
        },
      ),
    );

    await tester.tap(find.byType(NestedBackButton));
    await tester.pumpAndSettle();

    expect(find.text('Home fallback'), findsOneWidget);
  });

  test('app routes preserve native iOS back gesture support', () {
    final route = AppRouter.onGenerateRoute(
      const RouteSettings(name: AppRoutes.menu),
    );
    expect(route, isA<CupertinoPageRoute<dynamic>>());
  });

  test('malformed nested arguments do not throw during route creation', () {
    expect(
      () => AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.newsDetails, arguments: 42),
      ),
      returnsNormally,
    );
    expect(
      () => AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.requests, arguments: 42),
      ),
      returnsNormally,
    );
  });
}
