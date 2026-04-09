enum RequestStatus {
  newRequest(
    apiValue: 'new',
    label: 'Новая',
  ),
  inProgress(
    apiValue: 'in_progress',
    label: 'В работе',
  ),
  closed(
    apiValue: 'closed',
    label: 'Закрыта',
  );

  const RequestStatus({
    required this.apiValue,
    required this.label,
  });

  final String apiValue;
  final String label;

  factory RequestStatus.fromApi(String value) {
    switch (value) {
      case 'new':
        return RequestStatus.newRequest;
      case 'in_progress':
        return RequestStatus.inProgress;
      case 'closed':
        return RequestStatus.closed;
    }

    throw FormatException('Unknown request status: $value');
  }
}
