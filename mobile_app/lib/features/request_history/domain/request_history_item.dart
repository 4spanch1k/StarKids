import '../../requests/domain/request_status.dart';
import '../../requests/domain/request_type.dart';

class RequestHistoryBranchSummary {
  const RequestHistoryBranchSummary({
    required this.id,
    required this.name,
    required this.shortLabel,
  });

  final String id;
  final String name;
  final String shortLabel;
}

class RequestHistoryPackageSummary {
  const RequestHistoryPackageSummary({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class RequestHistoryItem {
  const RequestHistoryItem({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.requestedDate,
    this.guestCount,
    this.notes,
    this.branch,
    this.package,
  });

  final String id;
  final RequestType type;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime? requestedDate;
  final int? guestCount;
  final String? notes;
  final RequestHistoryBranchSummary? branch;
  final RequestHistoryPackageSummary? package;

  bool get hasNotes => (notes ?? '').trim().isNotEmpty;
}
