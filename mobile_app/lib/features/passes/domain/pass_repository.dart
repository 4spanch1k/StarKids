import '../../../core/utils/result.dart';
import 'pass.dart';

abstract interface class PassRepository {
  Future<Result<List<PassPlan>>> listPlans({String? branchId});

  Future<Result<List<CustomerPass>>> listPasses();

  Future<Result<CustomerPass>> getPass(String passId);

  Future<Result<String>> getPassQrPayload(String passId);

  Future<Result<PassQuote>> quote({
    required String childId,
    required String passPlanId,
    required String branchId,
  });

  Future<Result<PassPaymentStart>> startPayment({
    required String childId,
    required String passPlanId,
    required String branchId,
    required String idempotencyKey,
  });
}
