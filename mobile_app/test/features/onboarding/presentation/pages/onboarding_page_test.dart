import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/core/design_system/sk_color_scheme.dart';
import 'package:star_kids_mobile/core/design_system/sk_theme.dart';
import 'package:star_kids_mobile/core/utils/result.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_repository.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_session.dart';
import 'package:star_kids_mobile/features/auth/domain/mobile_auth_user.dart';
import 'package:star_kids_mobile/features/auth/domain/otp_challenge.dart';
import 'package:star_kids_mobile/features/auth/presentation/controllers/mobile_auth_controller.dart';
import 'package:star_kids_mobile/features/children/domain/child.dart';
import 'package:star_kids_mobile/features/onboarding/domain/onboarding_completion.dart';
import 'package:star_kids_mobile/features/onboarding/domain/onboarding_repository.dart';
import 'package:star_kids_mobile/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:star_kids_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:star_kids_mobile/features/profile/domain/user_profile.dart';

void main() {
  testWidgets('welcome requires parent name', (tester) async {
    final auth = await _authenticatedAuth('user-1');
    final onboarding = OnboardingController(
      authController: auth,
      repository: _FakeOnboardingRepository(),
    );

    await tester.pumpWidget(_testApp(OnboardingPage(controller: onboarding)));
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pump();

    expect(find.text('Введите ваше имя.'), findsOneWidget);
    expect(find.text('Фамилия (необязательно)'), findsOneWidget);
  });

  testWidgets('child count creates required sequential child steps', (
    tester,
  ) async {
    final auth = await _authenticatedAuth('user-2');
    final onboarding = OnboardingController(
      authController: auth,
      repository: _FakeOnboardingRepository(),
    );

    await tester.pumpWidget(_testApp(OnboardingPage(controller: onboarding)));
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Айжан');
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    expect(find.text('Сколько у вас детей?'), findsOneWidget);
    expect(find.text('Сделать позже'), findsNothing);
    await tester.tap(find.byTooltip('Увеличить количество детей'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Ребёнок 1 из 2'), findsOneWidget);
    expect(find.text('Не указывать'), findsOneWidget);

    await tester.tap(find.text('Далее'));
    await tester.pump();
    expect(find.text('Введите имя ребёнка.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Ая');
    await tester.tap(find.text('Далее'));
    await tester.pump();
    expect(find.text('Укажите дату рождения.'), findsOneWidget);
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    home: child,
    builder: (context, child) => SKTheme(
      dark: false,
      colors: SKColorScheme.light(),
      child: child!,
    ),
  );
}

Future<MobileAuthController> _authenticatedAuth(String userId) async {
  final auth = MobileAuthController(repository: _UnusedAuthRepository());
  await auth.loginWithEmail(
    email: '$userId@example.com',
    password: 'password',
  );
  return auth;
}

class _FakeOnboardingRepository implements OnboardingRepository {
  @override
  Future<Result<UserProfile>> fetchProfile() async => const Success(
        UserProfile(id: 'user-1'),
      );

  @override
  Future<Result<OnboardingCompletion>> complete({
    required String firstName,
    String? lastName,
    required List<OnboardingChildDraft> children,
    required String privacyConsentVersion,
  }) async {
    return Success(
      OnboardingCompletion(
        profile: UserProfile(
          id: 'user-1',
          firstName: firstName,
          lastName: lastName,
          onboardingCompleted: true,
        ),
        children: [
          for (var index = 0; index < children.length; index++)
            Child(
              id: 'child-$index',
              name: children[index].name,
              birthDate: children[index].birthDate,
              gender: children[index].gender,
            ),
        ],
      ),
    );
  }
}

class _UnusedAuthRepository implements MobileAuthRepository {
  @override
  Future<void> clearSession() async {}

  @override
  Future<Result<MobileAuthUser>> getCurrentUser(String accessToken) async =>
      const Failure('unused');

  @override
  Future<Result<MobileAuthSession>> exchangeClerkSession({
    required String sessionToken,
  }) async =>
      const Failure('unused');

  @override
  Future<Result<void>> logout(MobileAuthSession session) async =>
      const Success(null);

  @override
  Future<Result<MobileAuthSession>> refreshSession(String refreshToken) async =>
      const Failure('unused');

  @override
  Future<Result<MobileAuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) async =>
      const Failure('unused');

  @override
  Future<Result<MobileAuthSession>> loginWithEmail({
    required String email,
    required String password,
  }) async =>
      Success(
        MobileAuthSession(
          user: MobileAuthUser(id: email.split('@').first, email: email),
          email: email,
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          tokenType: 'bearer',
          verifiedAt: DateTime.utc(2026, 1, 1),
        ),
      );

  @override
  Future<Result<OtpChallenge>> requestOtp(String phone) async =>
      const Failure('unused');

  @override
  Future<MobileAuthSession?> restoreSession() async => null;

  @override
  Future<Result<MobileAuthSession?>> syncSession(
    MobileAuthSession session,
  ) async =>
      const Success(null);

  @override
  Future<Result<MobileAuthSession>> verifyOtp({
    required String phone,
    required String code,
    required String verificationId,
  }) async =>
      const Failure('unused');
}
