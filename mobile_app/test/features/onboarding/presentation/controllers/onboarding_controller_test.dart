import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

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
import 'package:star_kids_mobile/features/profile/domain/user_profile.dart';

void main() {
  test(
    'server profile controls onboarding requirement and completion payload',
    () async {
      final authRepository = _FakeAuthRepository(_session('user-a'));
      final auth = MobileAuthController(repository: authRepository);
      final onboardingRepository = _FakeOnboardingRepository(
        profile: const UserProfile(id: 'user-a'),
      );
      final onboarding = OnboardingController(
        authController: auth,
        repository: onboardingRepository,
      );

      await auth.loginWithEmail(email: 'a@example.com', password: 'password');
      await _settle();
      expect(onboarding.status, OnboardingStatus.required);

      final birthDate = DateTime(2020, 5, 6);
      final completed = await onboarding.complete(
        firstName: 'Айжан',
        children: [
          OnboardingChildDraft(
            name: 'Мадина',
            birthDate: birthDate,
            gender: ChildGender.female,
          ),
        ],
        privacyConsentVersion: 'v1',
      );

      expect(completed, isTrue);
      expect(onboarding.status, OnboardingStatus.complete);
      expect(onboardingRepository.lastFirstName, 'Айжан');
      expect(onboardingRepository.lastChildren.single.name, 'Мадина');
      expect(onboardingRepository.lastChildren.single.birthDate, birthDate);
    },
  );

  test(
    'stale completion cannot change the next account onboarding state',
    () async {
      final authRepository = _FakeAuthRepository(_session('user-a'));
      final auth = MobileAuthController(repository: authRepository);
      final onboardingRepository = _FakeOnboardingRepository(
        profile: const UserProfile(id: 'user-a'),
      );
      final onboarding = OnboardingController(
        authController: auth,
        repository: onboardingRepository,
      );

      await auth.loginWithEmail(email: 'a@example.com', password: 'password');
      await _settle();
      expect(onboarding.status, OnboardingStatus.required);

      final completion = Completer<Result<OnboardingCompletion>>();
      onboardingRepository.completionCompleter = completion;
      final staleCompletion = onboarding.complete(
        firstName: 'Айжан',
        children: const [],
        privacyConsentVersion: 'v1',
      );

      await auth.logout();
      authRepository.session = _session('user-b');
      onboardingRepository.profile = const UserProfile(id: 'user-b');
      await auth.loginWithEmail(email: 'b@example.com', password: 'password');
      await _settle();
      expect(onboarding.status, OnboardingStatus.required);

      completion.complete(
        const Success<OnboardingCompletion>(
          OnboardingCompletion(
            profile: UserProfile(
              id: 'user-a',
              onboardingCompleted: true,
            ),
            children: [],
          ),
        ),
      );

      expect(await staleCompletion, isFalse);
      expect(onboarding.status, OnboardingStatus.required);
      expect(onboarding.completion, isNull);
    },
  );

  test(
    'logout clears onboarding state and the next account uses server state',
    () async {
      final authRepository = _FakeAuthRepository(_session('user-a'));
      final auth = MobileAuthController(repository: authRepository);
      final onboardingRepository = _FakeOnboardingRepository(
        profile: const UserProfile(id: 'user-a', onboardingCompleted: true),
      );
      final onboarding = OnboardingController(
        authController: auth,
        repository: onboardingRepository,
      );

      await auth.loginWithEmail(email: 'a@example.com', password: 'password');
      await _settle();
      expect(onboarding.isComplete, isTrue);

      await auth.logout();
      expect(onboarding.status, OnboardingStatus.idle);
      expect(onboarding.completion, isNull);

      authRepository.session = _session('user-b');
      onboardingRepository.profile = const UserProfile(id: 'user-b');
      await auth.loginWithEmail(email: 'b@example.com', password: 'password');
      await _settle();
      expect(onboarding.status, OnboardingStatus.required);
    },
  );
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

MobileAuthSession _session(String userId) => MobileAuthSession(
      user: MobileAuthUser(id: userId, email: '$userId@example.com'),
      email: '$userId@example.com',
      accessToken: 'access-$userId',
      refreshToken: 'refresh-$userId',
      tokenType: 'bearer',
      verifiedAt: DateTime.utc(2026, 1, 1),
    );

class _FakeOnboardingRepository implements OnboardingRepository {
  _FakeOnboardingRepository({required this.profile});

  UserProfile profile;
  String? lastFirstName;
  List<OnboardingChildDraft> lastChildren = const [];
  Completer<Result<OnboardingCompletion>>? completionCompleter;

  @override
  Future<Result<UserProfile>> fetchProfile() async =>
      Success<UserProfile>(profile);

  @override
  Future<Result<OnboardingCompletion>> complete({
    required String firstName,
    required List<OnboardingChildDraft> children,
    required String privacyConsentVersion,
  }) async {
    if (completionCompleter != null) return completionCompleter!.future;
    lastFirstName = firstName;
    lastChildren = children;
    profile = profile.copyWith(firstName: firstName, onboardingCompleted: true);
    return Success<OnboardingCompletion>(
      OnboardingCompletion(
        profile: profile,
        children: [
          for (final child in children)
            Child(
              id: child.name,
              name: child.name,
              birthDate: child.birthDate,
              gender: child.gender,
            ),
        ],
      ),
    );
  }
}

class _FakeAuthRepository implements MobileAuthRepository {
  _FakeAuthRepository(this.session);

  MobileAuthSession session;

  @override
  Future<void> clearSession() async {}

  @override
  Future<Result<MobileAuthUser>> getCurrentUser(String accessToken) async =>
      Success<MobileAuthUser>(session.user!);

  @override
  Future<Result<MobileAuthSession>> exchangeClerkSession({
    required String sessionToken,
  }) async =>
      Success<MobileAuthSession>(session);

  @override
  Future<Result<void>> logout(MobileAuthSession session) async =>
      const Success<void>(null);

  @override
  Future<Result<MobileAuthSession>> refreshSession(String refreshToken) async =>
      Success<MobileAuthSession>(session);

  @override
  Future<Result<MobileAuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) async =>
      Success<MobileAuthSession>(session);

  @override
  Future<Result<MobileAuthSession>> loginWithEmail({
    required String email,
    required String password,
  }) async =>
      Success<MobileAuthSession>(session);

  @override
  Future<Result<OtpChallenge>> requestOtp(String phone) async =>
      const Failure<OtpChallenge>('unused');

  @override
  Future<MobileAuthSession?> restoreSession() async => session;

  @override
  Future<Result<MobileAuthSession?>> syncSession(
    MobileAuthSession session,
  ) async =>
      Success<MobileAuthSession?>(this.session);

  @override
  Future<Result<MobileAuthSession>> verifyOtp({
    required String phone,
    required String code,
    required String verificationId,
  }) async =>
      Success<MobileAuthSession>(session);
}
