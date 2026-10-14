import '../../../core/utils/result.dart';
import 'customer_qr.dart';

abstract interface class CustomerQrRepository {
  Future<Result<CustomerQr>> fetchCustomerQr();
}
