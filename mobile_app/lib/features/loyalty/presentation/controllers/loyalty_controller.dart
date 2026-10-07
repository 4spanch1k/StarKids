import 'package:flutter/foundation.dart';

import '../../../../core/utils/result.dart';
import '../../domain/loyalty_account.dart';
import '../../domain/loyalty_repository.dart';
import '../../domain/loyalty_transaction.dart';

enum LoyaltyViewStatus { idle, loading, success, error }

class LoyaltyController extends ChangeNotifier {
  LoyaltyController({required LoyaltyRepository repository, this.pageSize = 20})
      : _repository = repository;
  final LoyaltyRepository _repository;
  final int pageSize;
  LoyaltyViewStatus _status = LoyaltyViewStatus.idle;
  LoyaltyAccount? _account;
  String? _errorMessage;
  List<LoyaltyTransaction> _transactions = const [];
  String? _transactionsErrorMessage;
  bool _transactionsLoading = false;
  bool _hasMoreTransactions = true;
  int _transactionsOffset = 0;
  LoyaltyViewStatus get status => _status;
  LoyaltyAccount? get account => _account;
  String? get errorMessage => _errorMessage;
  List<LoyaltyTransaction> get transactions => List.unmodifiable(_transactions);
  String? get transactionsErrorMessage => _transactionsErrorMessage;
  bool get transactionsLoading => _transactionsLoading;
  bool get hasMoreTransactions => _hasMoreTransactions;

  Future<void> load({bool refreshTransactions = true}) async {
    _status = LoyaltyViewStatus.loading;
    _errorMessage = null;
    if (refreshTransactions) {
      _transactions = const [];
      _transactionsOffset = 0;
      _hasMoreTransactions = true;
      _transactionsErrorMessage = null;
    }
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
    if (refreshTransactions) {
      await _loadTransactionsPage(reset: true);
    }
  }

  Future<void> loadMoreTransactions() async {
    if (_transactionsLoading || !_hasMoreTransactions) return;
    await _loadTransactionsPage();
  }

  Future<void> _loadTransactionsPage({bool reset = false}) async {
    if (_transactionsLoading) return;
    _transactionsLoading = true;
    if (reset) {
      _transactions = const [];
      _transactionsOffset = 0;
      _hasMoreTransactions = true;
      _transactionsErrorMessage = null;
    }
    notifyListeners();
    final result = await _repository.fetchTransactions(
      limit: pageSize,
      offset: _transactionsOffset,
    );
    if (result is Success<List<LoyaltyTransaction>>) {
      final next = result.data;
      _transactions = [..._transactions, ...next];
      _transactionsOffset = _transactions.length;
      _hasMoreTransactions = next.length >= pageSize;
      _transactionsErrorMessage = null;
    } else {
      _transactionsErrorMessage =
          (result as Failure<List<LoyaltyTransaction>>).message;
    }
    _transactionsLoading = false;
    notifyListeners();
  }
}
