import '../../children/data/children_api_models.dart';
import '../../profile/data/profile_api_models.dart';
import '../domain/onboarding_completion.dart';

class OnboardingCompletionDto {
  const OnboardingCompletionDto({
    required this.profile,
    required this.children,
  });

  final UserProfileDto profile;
  final List<ChildDto> children;

  factory OnboardingCompletionDto.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    return OnboardingCompletionDto(
      profile: UserProfileDto.fromJson(
        (json['profile'] as Map<String, dynamic>?) ?? const {},
      ),
      children: rawChildren is List
          ? rawChildren
              .whereType<Map<String, dynamic>>()
              .map(ChildDto.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  OnboardingCompletion toDomain() => OnboardingCompletion(
        profile: profile.toDomain(),
        children:
            children.map((child) => child.toDomain()).toList(growable: false),
      );
}
