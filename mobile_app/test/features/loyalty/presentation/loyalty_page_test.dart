import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/features/loyalty/domain/loyalty_account.dart';
import 'package:star_kids_mobile/features/loyalty/domain/loyalty_repository.dart';
import 'package:star_kids_mobile/features/loyalty/domain/loyalty_transaction.dart';
import 'package:star_kids_mobile/features/loyalty/presentation/controllers/loyalty_controller.dart';
import 'package:star_kids_mobile/features/loyalty/presentation/pages/loyalty_page.dart';
import 'package:star_kids_mobile/core/utils/result.dart';

import '../../../helpers/test_app_harness.dart';

void main() {
  testWidgets('renders balance, lifetime metrics and transaction history',
      (tester) async {
    final controller = LoyaltyController(repository: _PageRepository());
    await tester
        .pumpWidget(buildTestApp(child: LoyaltyPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('1 250 бонусов'), findsOneWidget);
    expect(find.text('Начислено всего'), findsOneWidget);
    expect(find.text('Начисление бонусов'), findsOneWidget);
    expect(find.text('+250 б.'), findsOneWidget);
  });
}

class _PageRepository implements LoyaltyRepository {
  @override
  Future<Result<LoyaltyAccount>> fetchAccount() async => const Success(
        LoyaltyAccount(
          balance: 1250,
          reservedBalance: 0,
          availableBalance: 1250,
          lifetimeEarned: 2000,
          lifetimeSpent: 750,
        ),
      );

  @override
  Future<Result<List<LoyaltyTransaction>>> fetchTransactions(
          {int limit = 20, int offset = 0}) async =>
      Success([
        LoyaltyTransaction(
          id: 'earn-1',
          type: 'earn',
          amount: 250,
          balanceDelta: 250,
          reservedDelta: 0,
          sourceType: 'test',
          sourceId: 'source-1',
          status: 'posted',
          description: null,
          createdAt: DateTime(2026, 9, 7),
        ),
      ]);
}
