enum RequestStatus {
  newRequest(apiValue: 'new', label: 'Новая'),
  contacted(apiValue: 'contacted', label: 'Менеджер связался'),
  qualified(apiValue: 'qualified', label: 'Детали уточняются'),
  booked(apiValue: 'booked', label: 'Праздник забронирован'),
  paid(apiValue: 'paid', label: 'Праздник забронирован'),
  completed(apiValue: 'completed', label: 'Праздник проведён'),
  lost(apiValue: 'lost', label: 'Не состоялось'),

  // Historical values remain readable for older requests.
  inProgress(apiValue: 'in_progress', label: 'В работе'),
  closed(apiValue: 'closed', label: 'Закрыта'),
  confirmed(apiValue: 'confirmed', label: 'Праздник подтверждён'),
  cancelled(apiValue: 'cancelled', label: 'Отменено');

  const RequestStatus({required this.apiValue, required this.label});

  final String apiValue;
  final String label;

  /// Copy for compact parent-facing surfaces. The persisted enum and the
  /// existing history labels remain unchanged.
  String get userFacingLabel => switch (this) {
        RequestStatus.newRequest => 'Заявка отправлена',
        RequestStatus.contacted => 'Менеджер связался',
        RequestStatus.qualified => 'Детали уточняются',
        RequestStatus.booked => 'Праздник забронирован',
        RequestStatus.paid => 'Праздник забронирован',
        RequestStatus.completed => 'Праздник проведён',
        RequestStatus.inProgress => 'Заявка в работе',
        RequestStatus.confirmed => 'Праздник подтверждён',
        RequestStatus.cancelled => 'Отменено',
        RequestStatus.lost => 'Не состоялось',
        RequestStatus.closed => 'Закрыта',
      };

  factory RequestStatus.fromApi(String value) {
    switch (value) {
      case 'new':
        return RequestStatus.newRequest;
      case 'contacted':
        return RequestStatus.contacted;
      case 'qualified':
        return RequestStatus.qualified;
      case 'booked':
        return RequestStatus.booked;
      case 'paid':
        return RequestStatus.paid;
      case 'completed':
        return RequestStatus.completed;
      case 'in_progress':
        return RequestStatus.inProgress;
      case 'closed':
        return RequestStatus.closed;
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
