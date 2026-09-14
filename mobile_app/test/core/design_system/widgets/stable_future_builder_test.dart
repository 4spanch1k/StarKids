import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/core/design_system/widgets/stable_future_builder.dart';

void main() {
  testWidgets('reuses its future until the cache key changes', (tester) async {
    var calls = 0;
    var cacheKey = 'branch-a';
    late StateSetter rebuild;

    Future<String> load() async {
      calls += 1;
      return cacheKey;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return StableFutureBuilder<String>(
              cacheKey: cacheKey,
              futureFactory: load,
              builder: (context, snapshot) => Text(snapshot.data ?? 'loading'),
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(calls, 1);
    expect(find.text('branch-a'), findsOneWidget);

    rebuild(() {});
    await tester.pump();
    expect(calls, 1);

    cacheKey = 'branch-b';
    rebuild(() {});
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(find.text('branch-b'), findsOneWidget);
  });
}
