import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/features/requests/domain/request_status.dart';

void main() {
  test('paid birthday lead keeps parent-facing booked copy', () {
    final status = RequestStatus.fromApi('paid');

    expect(status, RequestStatus.paid);
    expect(status.userFacingLabel, 'Праздник забронирован');
  });
}
