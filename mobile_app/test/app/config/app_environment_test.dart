import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/app/config/app_environment.dart';

void main() {
  test('birthday requests use the live backend by default', () {
    expect(AppEnvironment.useMockBirthdayRequests, isFalse);
  });
}
