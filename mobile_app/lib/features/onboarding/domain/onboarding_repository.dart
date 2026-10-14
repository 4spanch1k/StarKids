import '../../../core/utils/result.dart';
import '../../children/domain/child.dart';
import '../../profile/domain/user_profile.dart';
import 'onboarding_completion.dart';

abstract interface class OnboardingRepository {
  Future<Result<UserProfile>> fetchProfile();

  Future<Result<OnboardingCompletion>> complete({
    required String firstName,
    required List<OnboardingChildDraft> children,
    required String privacyConsentVersion,
  });
}

class OnboardingChildDraft {
  const OnboardingChildDraft({
    required this.name,
    required this.birthDate,
    required this.gender,
  });

  final String name;
  final DateTime birthDate;
  final ChildGender gender;
}
