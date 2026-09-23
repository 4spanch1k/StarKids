import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:star_kids_mobile/features/home/presentation/models/home_visit_copy.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  group('formatVisitCount', () {
    test('uses correct Russian visit plural forms', () {
      expect(formatVisitCount(1), '1 раз');
      expect(formatVisitCount(2), '2 раза');
      expect(formatVisitCount(5), '5 раз');
      expect(formatVisitCount(11), '11 раз');
      expect(formatVisitCount(21), '21 раз');
      expect(formatVisitCount(22), '22 раза');
      expect(formatVisitCount(25), '25 раз');
    });
  });

  test('formats the last visit in local time with a readable date', () {
    expect(formatLastVisitDate(DateTime(2026, 9, 5, 15)), '5 сентября');
  });
}
