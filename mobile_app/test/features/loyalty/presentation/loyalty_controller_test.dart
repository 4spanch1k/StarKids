import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/loyalty/domain/loyalty_account.dart';
import 'package:star_kids_mobile/features/loyalty/domain/loyalty_repository.dart';
import 'package:star_kids_mobile/features/loyalty/domain/loyalty_transaction.dart';
import 'package:star_kids_mobile/features/loyalty/presentation/controllers/loyalty_controller.dart';

void main() {
  test('loads account and first transaction page', () async {
    final repository = _FakeLoyaltyRepository(
      transactions: [_transaction('earn-1', type: 'earn', amount: 250)],
    );
    final controller = LoyaltyController(repository: repository, pageSize: 1);

    await controller.load();

    expect(controller.status, LoyaltyViewStatus.success);
    expect(controller.account?.balance, 1250);
    expect(controller.transactions, hasLength(1));
    expect(controller.hasMoreTransactions, true);
  });

  test('paginates without duplicating transactions', () async {
    final repository = _FakeLoyaltyRepository(
      transactions: [
        _transaction('earn-1', type: 'earn', amount: 250),
        _transaction('spend-1', type: 'capture', amount: 100),
      ],
    );
    final controller = LoyaltyController(repository: repository, pageSize: 1);

    await controller.load();
    await controller.loadMoreTransactions();
    await controller.loadMoreTransactions();

    expect(
        controller.transactions.map((item) => item.id), ['earn-1', 'spend-1']);
    expect(controller.hasMoreTransactions, false);
  });
}

class _FakeLoyaltyRepository implements LoyaltyRepository {
  _FakeLoyaltyRepository({required this.transactions});
  final List<LoyaltyTransaction> transactions;

  @override
  Future<Result<LoyaltyAccount>> fetchAccount() async => const Success(
        LoyaltyAccount(
          balance: 1250,
          reservedBalance: 100,
          availableBalance: 1150,
          lifetimeEarned: 2000,
          lifetimeSpent: 750,
        ),
      );

  @override
  Future<Result<List<LoyaltyTransaction>>> fetchTransactions({
    int limit = 20,
    int offset = 0,
  }) async =>
      Success(transactions.skip(offset).take(limit).toList());
}

LoyaltyTransaction _transaction(String id,
        {required String type, required int amount}) =>
    LoyaltyTransaction(
      id: id,
      type: type,
      amount: amount,
      balanceDelta: type == 'earn' ? amount : -amount,
      reservedDelta: 0,
      sourceType: 'mobile_payment',
      sourceId: 'source-$id',
      status: 'posted',
      description: null,
      createdAt: DateTime(2026, 9, 7),
    );
