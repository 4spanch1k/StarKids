import '../../children/domain/child.dart';
import '../../profile/domain/user_profile.dart';

class OnboardingCompletion {
  const OnboardingCompletion({required this.profile, required this.children});

  final UserProfile profile;
  final List<Child> children;
}
