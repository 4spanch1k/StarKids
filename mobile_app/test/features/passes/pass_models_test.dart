import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:star_kids_mobile/core/storage/local_storage.dart';
import 'package:star_kids_mobile/features/passes/data/pass_api_models.dart';
import 'package:star_kids_mobile/features/passes/domain/pass.dart';

void main() {
  test('pass API models preserve authoritative plan and pass fields', () {
    final plan = PassPlanDto.fromJson({
      'id': 'plan-4',
      'name': 'BOOM 4',
      'priceTenge': 10000,
      'visitLimit': 4,
      'validityDays': 30,
      'dailyLimit': 1,
      'branchId': null,
      'isActive': true,
    }).toDomain();
    final pass = CustomerPassDto.fromJson({
      'id': 'pass-1',
      'childId': 'child-1',
      'childName': 'Алия',
      'passPlanId': plan.id,
      'planName': plan.name,
      'priceTenge': plan.priceTenge,
      'visitLimit': plan.visitLimit,
      'validityDays': plan.validityDays,
      'dailyLimit': plan.dailyLimit,
      'branchId': null,
      'activatedAt': '2026-09-20T00:00:00Z',
      'expiresAt': '2026-10-20T00:00:00Z',
      'remainingVisits': 4,
      'status': 'active',
    }).toDomain();

    expect(plan.name, 'BOOM 4');
    expect(pass.status, CustomerPassStatus.active);
    expect(pass.remainingVisits, 4);
    expect(pass.branchId, isNull);
  });

  test('pass QR cache is persisted by pass id and can be cleared', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorage();
    await storage.savePassQrPayload('pass-1', 'bb_pass:v1:pass-1:sig');
    expect(await storage.readPassQrPayload('pass-1'), 'bb_pass:v1:pass-1:sig');
    await storage.clearPassQrPayload('pass-1');
    expect(await storage.readPassQrPayload('pass-1'), isNull);
  });

  test('pass payment init reads the shared backend amount fields', () {
    final payment = passPaymentStartFromJson({
      'paymentId': 'payment-1',
      'localOrderId': 'order-1',
      'externalPaymentId': 'external-1',
      'paymentUrl': 'https://customer.freedompay.kz/pay/1',
      'status': 'pending',
      'grossAmountTenge': 10000,
      'cashAmountTenge': 10000,
    });

    expect(payment.amountTenge, 10000);
  });
}
