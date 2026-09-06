import 'package:flutter/foundation.dart';

import '../../../../core/utils/result.dart';
import '../../domain/loyalty_account.dart';
import '../../domain/loyalty_repository.dart';

enum LoyaltyViewStatus { idle, loading, success, error }

class LoyaltyController extends ChangeNotifier {
  LoyaltyController({required LoyaltyRepository repository}) : _repository = repository;
  final LoyaltyRepository _repository;
  LoyaltyViewStatus _status = LoyaltyViewStatus.idle;
  LoyaltyAccount? _account;
  String? _errorMessage;
  LoyaltyViewStatus get status => _status;
  LoyaltyAccount? get account => _account;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _status = LoyaltyViewStatus.loading;
    _errorMessage = null;
    notifyListeners();
    final result = await _repository.fetchAccount();
    if (result is Success<LoyaltyAccount>) {
      _account = result.data;
      _status = LoyaltyViewStatus.success;
    } else {
      _status = LoyaltyViewStatus.error;
      _errorMessage = (result as Failure<LoyaltyAccount>).message;
    }
    notifyListeners();
  }
}
