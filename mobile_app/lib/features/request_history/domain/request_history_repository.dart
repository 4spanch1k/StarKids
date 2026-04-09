import 'request_history_item.dart';

abstract interface class RequestHistoryRepository {
  Future<RequestHistoryFetchResult> fetchMyRequests();
}

abstract class RequestHistoryFetchResult {
  const RequestHistoryFetchResult();
}

class RequestHistoryFetchSuccess extends RequestHistoryFetchResult {
  const RequestHistoryFetchSuccess({
    required this.items,
    required this.total,
  });

  final List<RequestHistoryItem> items;
  final int total;
}

class RequestHistoryFetchUnauthenticated extends RequestHistoryFetchResult {
  const RequestHistoryFetchUnauthenticated();
}

class RequestHistoryFetchFailure extends RequestHistoryFetchResult {
  const RequestHistoryFetchFailure(this.message);

  final String message;
}
