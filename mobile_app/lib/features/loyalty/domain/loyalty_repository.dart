import '../../../core/utils/result.dart';
import 'loyalty_account.dart';
import 'loyalty_transaction.dart';

abstract interface class LoyaltyRepository {
  Future<Result<LoyaltyAccount>> fetchAccount();
  Future<Result<List<LoyaltyTransaction>>> fetchTransactions({int limit = 20, int offset = 0});
}
