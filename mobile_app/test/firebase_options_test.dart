import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_kids_mobile/firebase_options.dart';

void main() {
  test('production-shaped Boom Bala options are not treated as placeholders', () {
    const options = FirebaseOptions(
      apiKey: 'client-api-key',
      appId: '1:491968637725:android:production',
      messagingSenderId: '491968637725',
      projectId: 'boom-bala-production',
    );

    expect(DefaultFirebaseOptions.isConfiguredFor(options), isTrue);
  });

  test('placeholder Firebase options stay disabled', () {
    const options = FirebaseOptions(
      apiKey: 'PLACEHOLDER_API_KEY',
      appId: 'PLACEHOLDER_APP_ID',
      messagingSenderId: 'PLACEHOLDER_SENDER_ID',
      projectId: 'project-id-placeholder',
      iosBundleId: 'com.example.starKidsMobile',
    );

    expect(DefaultFirebaseOptions.isConfiguredFor(options), isFalse);
  });

  test('production iOS options accept the approved bundle identifier', () {
    const options = FirebaseOptions(
      apiKey: 'client-api-key',
      appId: '1:491968637725:ios:production',
      messagingSenderId: '491968637725',
      projectId: 'boom-bala-production',
      iosBundleId: 'kz.boombala.app',
    );

    expect(DefaultFirebaseOptions.isConfiguredFor(options), isTrue);
  });
}
