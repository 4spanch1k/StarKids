import 'package:intl/intl.dart';

String formatVisitCount(int count) {
  final normalized = count < 0 ? 0 : count;
  final lastDigit = normalized % 10;
  final lastTwoDigits = normalized % 100;
  final noun = lastDigit == 1 && lastTwoDigits != 11
      ? 'раз'
      : (lastDigit >= 2 &&
                lastDigit <= 4 &&
                (lastTwoDigits < 10 || lastTwoDigits >= 20)
            ? 'раза'
            : 'раз');
  return '$normalized $noun';
}

String formatLastVisitDate(DateTime value) {
  return DateFormat('d MMMM', 'ru').format(value.toLocal());
}
