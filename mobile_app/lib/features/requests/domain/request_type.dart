enum RequestType {
  birthdayRequest(
    apiValue: 'birthday_request',
    label: 'День рождения',
    selectorDescription:
        'Праздник с выбором филиала, пакета, даты и количества гостей.',
    screenTitle: 'Заявка',
    formTitle: 'Соберём праздник за пару минут',
    formDescription:
        'Филиал и пакет уже под рукой. Осталось указать контакт и удобную дату.',
    submitButtonLabel: 'Отправить заявку',
    successTitle: 'Заявка отправлена',
    successDescription:
        'Мы уже передали запрос менеджеру Boom Bala. Дальше с вами свяжутся, чтобы подтвердить детали праздника.',
    fallbackHistoryNotes:
        'Заявка на день рождения отправлена. Менеджер свяжется с вами для уточнения деталей.',
    createAnotherLabel: 'Оставить еще одну заявку',
  ),
  contact(
    apiValue: 'contact',
    label: 'Менеджеру',
    selectorDescription:
        'Короткий запрос по филиалу, маршруту, свободным датам или услугам.',
    screenTitle: 'Менеджеру',
    formTitle: 'Короткий запрос без переписок',
    formDescription:
        'Опишите вопрос — перезвоним и поможем без лишних уточнений.',
    submitButtonLabel: 'Отправить запрос',
    successTitle: 'Запрос отправлен',
    successDescription:
        'Мы уже передали запрос менеджеру Boom Bala. С вами свяжутся по указанному номеру, чтобы помочь с выбором.',
    fallbackHistoryNotes:
        'Запрос на обратную связь отправлен. Менеджер свяжется с вами по указанному номеру.',
    createAnotherLabel: 'Оставить еще один запрос',
  );

  const RequestType({
    required this.apiValue,
    required this.label,
    required this.selectorDescription,
    required this.screenTitle,
    required this.formTitle,
    required this.formDescription,
    required this.submitButtonLabel,
    required this.successTitle,
    required this.successDescription,
    required this.fallbackHistoryNotes,
    required this.createAnotherLabel,
  });

  final String apiValue;
  final String label;
  final String selectorDescription;
  final String screenTitle;
  final String formTitle;
  final String formDescription;
  final String submitButtonLabel;
  final String successTitle;
  final String successDescription;
  final String fallbackHistoryNotes;
  final String createAnotherLabel;

  bool get isBirthdayRequest => this == RequestType.birthdayRequest;

  factory RequestType.fromApi(String value) {
    switch (value) {
      case 'birthday_request':
        return RequestType.birthdayRequest;
      case 'contact':
        return RequestType.contact;
    }

    throw FormatException('Unknown request type: $value');
  }
}
