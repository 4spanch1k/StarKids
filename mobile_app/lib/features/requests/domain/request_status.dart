enum RequestStatus {
  newRequest(apiValue: 'new', label: 'Новая'),
  inProgress(apiValue: 'in_progress', label: 'В работе'),
  closed(apiValue: 'closed', label: 'Закрыта'),

  // Birthday lead v2 statuses. Legacy in_progress/closed remain supported
  // for older contact requests and historical records.
  contacted(apiValue: 'contacted', label: 'Менеджер связался'),
  confirmed(apiValue: 'confirmed', label: 'Праздник подтверждён'),
  cancelled(apiValue: 'cancelled', label: 'Отменено'),
  lost(apiValue: 'lost', label: 'Не состоялось');

  const RequestStatus({required this.apiValue, required this.label});

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
      case 'contacted':
        return RequestStatus.contacted;
      case 'confirmed':
        return RequestStatus.confirmed;
      case 'cancelled':
        return RequestStatus.cancelled;
      case 'lost':
        return RequestStatus.lost;
    }
    return RequestStatus.newRequest;
  }
}
