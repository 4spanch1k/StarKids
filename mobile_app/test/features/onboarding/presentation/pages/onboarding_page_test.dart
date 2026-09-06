import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:star_kids_mobile/app/router/app_routes.dart';
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
  testWidgets('zero-child onboarding completes and navigates to Home', (
    tester,
  ) async {
    final auth = MobileAuthController(repository: _UnusedAuthRepository());
    final onboarding = OnboardingController(
      authController: auth,
      repository: _FakeOnboardingRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.home: (_) => const Scaffold(body: Text('Home')),
        },
        home: OnboardingPage(controller: onboarding),
        builder: (context, child) => SKTheme(
          dark: false,
          colors: SKColorScheme.light(),
          child: child!,
        ),
      ),
    );

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Айжан');
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '0'));
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('Сохранить и продолжить'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(onboarding.status, OnboardingStatus.complete);
  });
}

class _FakeOnboardingRepository implements OnboardingRepository {
  @override
  Future<Result<UserProfile>> fetchProfile() async => const Success(
        UserProfile(id: 'user-1'),
      );

  @override
  Future<Result<OnboardingCompletion>> complete({
    required String firstName,
    required List<OnboardingChildDraft> children,
    required String privacyConsentVersion,
  }) async {
    return Success(
      OnboardingCompletion(
        profile: UserProfile(
          id: 'user-1',
          firstName: firstName,
          onboardingCompleted: true,
        ),
        children: const <Child>[],
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
      const Failure('unused');

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
