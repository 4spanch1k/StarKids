import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/features/loyalty/domain/loyalty_transaction.dart';
import 'package:star_kids_mobile/features/loyalty/presentation/loyalty_transaction_presentation.dart';

void main() {
  test('hides reservation and release movements from customer history', () {
    final presentation =
        presentLoyaltyTransaction(_transaction('reserve', 'reserve'));
    expect(presentation.amountLabel, isEmpty);
  });

  test('maps earn, spend and reversal to explicit customer copy', () {
    expect(presentLoyaltyTransaction(_transaction('earn', 'earn')).title,
        'Начисление бонусов');
    expect(
        presentLoyaltyTransaction(_transaction('capture', 'capture'))
            .amountLabel,
        '-100');
    expect(
        presentLoyaltyTransaction(_transaction('reversal', 'reversal')).title,
        'Отмена начисления');
  });
}

LoyaltyTransaction _transaction(String id, String type) => LoyaltyTransaction(
      id: id,
      type: type,
      amount: 100,
      balanceDelta: type == 'earn' ? 100 : -100,
      reservedDelta: type == 'reserve' ? 100 : 0,
      sourceType: 'test',
      sourceId: 'source-$id',
      status: 'posted',
      description: null,
      createdAt: DateTime(2026, 9, 7),
    );
