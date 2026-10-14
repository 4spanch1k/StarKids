class CurrentVisit {
  const CurrentVisit({
    required this.visitId,
    required this.branchId,
    required this.branchName,
    required this.status,
    required this.startedAt,
  });

  final String visitId;
  final String branchId;
  final String branchName;
  final String status;
  final DateTime startedAt;
}

class VisitHistory {
  const VisitHistory({
    required this.visitCount,
    required this.firstVisitAt,
    required this.lastVisitAt,
    required this.items,
  });

  final int visitCount;
  final DateTime? firstVisitAt;
  final DateTime? lastVisitAt;
  final List<VisitHistoryItem> items;

  bool get hasCompletedVisit => visitCount > 0;
}

class VisitHistoryItem {
  const VisitHistoryItem({
    required this.visitId,
    required this.branchId,
    required this.branchName,
    required this.startedAt,
    required this.endedAt,
  });

  final String visitId;
  final String branchId;
  final String branchName;
  final DateTime startedAt;
  final DateTime? endedAt;
}
