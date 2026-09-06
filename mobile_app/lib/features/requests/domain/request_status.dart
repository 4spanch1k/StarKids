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

  /// Copy for compact parent-facing surfaces. The persisted enum and the
  /// existing history labels remain unchanged.
  String get userFacingLabel => switch (this) {
        RequestStatus.newRequest => 'Заявка отправлена',
        RequestStatus.inProgress => 'Заявка в работе',
        RequestStatus.contacted => 'Менеджер связался',
        RequestStatus.confirmed => 'Праздник подтверждён',
        RequestStatus.cancelled => 'Отменено',
        RequestStatus.lost => 'Не состоялось',
        RequestStatus.closed => 'Закрыта',
      };

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
