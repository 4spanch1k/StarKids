enum RequestHistoryType {
  birthdayRequest,
  contact;

  factory RequestHistoryType.fromApi(String value) {
    switch (value) {
      case 'birthday_request':
        return RequestHistoryType.birthdayRequest;
      case 'contact':
        return RequestHistoryType.contact;
    }

    throw FormatException('Unknown request history type: $value');
  }

  String get label {
    switch (this) {
      case RequestHistoryType.birthdayRequest:
        return 'День рождения';
      case RequestHistoryType.contact:
        return 'Связь с менеджером';
    }
  }
}

enum RequestHistoryStatus {
  newRequest,
  inProgress,
  closed;

  factory RequestHistoryStatus.fromApi(String value) {
    switch (value) {
      case 'new':
        return RequestHistoryStatus.newRequest;
      case 'in_progress':
        return RequestHistoryStatus.inProgress;
      case 'closed':
        return RequestHistoryStatus.closed;
    }

    throw FormatException('Unknown request history status: $value');
  }

  String get label {
    switch (this) {
      case RequestHistoryStatus.newRequest:
        return 'Новая';
      case RequestHistoryStatus.inProgress:
        return 'В работе';
      case RequestHistoryStatus.closed:
        return 'Закрыта';
    }
  }
}

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
  final RequestHistoryType type;
  final RequestHistoryStatus status;
  final DateTime createdAt;
  final DateTime? requestedDate;
  final int? guestCount;
  final String? notes;
  final RequestHistoryBranchSummary? branch;
  final RequestHistoryPackageSummary? package;

  bool get hasNotes => (notes ?? '').trim().isNotEmpty;
}
