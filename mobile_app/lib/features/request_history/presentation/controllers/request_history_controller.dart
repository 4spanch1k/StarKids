import 'package:flutter/material.dart';

import '../../domain/request_history_item.dart';
import '../../domain/request_history_repository.dart';

enum RequestHistoryViewStatus {
  idle,
  loading,
  loaded,
  empty,
  error,
  unauthenticated,
}

class RequestHistoryController extends ChangeNotifier {
  RequestHistoryController({
    required RequestHistoryRepository repository,
  }) : _repository = repository;

  final RequestHistoryRepository _repository;

  RequestHistoryViewStatus _status = RequestHistoryViewStatus.idle;
  List<RequestHistoryItem> _items = const [];
  int _total = 0;
  String? _errorMessage;
  bool _isDisposed = false;

  RequestHistoryViewStatus get status => _status;
  List<RequestHistoryItem> get items => _items;
  int get total => _total;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == RequestHistoryViewStatus.loading;

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> load() async {
    if (_status == RequestHistoryViewStatus.loading) {
      return;
    }

    _status = RequestHistoryViewStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.fetchMyRequests();

    if (result is RequestHistoryFetchSuccess) {
      _items = result.items;
      _total = result.total;
      _status = result.items.isEmpty
          ? RequestHistoryViewStatus.empty
          : RequestHistoryViewStatus.loaded;
    } else if (result is RequestHistoryFetchUnauthenticated) {
      _items = const [];
      _total = 0;
      _status = RequestHistoryViewStatus.unauthenticated;
    } else if (result is RequestHistoryFetchFailure) {
      _items = const [];
      _total = 0;
      _errorMessage = result.message;
      _status = RequestHistoryViewStatus.error;
    }

    notifyListeners();
  }
}
