import '../domain/user_profile.dart';

class UserProfileDto {
  const UserProfileDto({
    required this.id,
    this.phone,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.email,
    this.childBirthDate,
    this.onboardingCompleted = false,
    this.onboardingCompletedAt,
    this.privacyConsentAt,
    this.privacyConsentVersion,
  });

  final String id;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? email;
  final DateTime? childBirthDate;
  final bool onboardingCompleted;
  final DateTime? onboardingCompletedAt;
  final DateTime? privacyConsentAt;
  final String? privacyConsentVersion;

  factory UserProfileDto.fromJson(Map<String, dynamic> json) {
    return UserProfileDto(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      email: json['email'] as String?,
      childBirthDate: _parseDate(json['childBirthDate'] as String?),
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      onboardingCompletedAt: _parseDate(
        json['onboardingCompletedAt'] as String?,
      ),
      privacyConsentAt: _parseDate(json['privacyConsentAt'] as String?),
      privacyConsentVersion: json['privacyConsentVersion'] as String?,
    );
  }

  UserProfile toDomain() {
    return UserProfile(
      id: id,
      phone: phone,
      firstName: firstName,
      lastName: lastName,
      avatarUrl: avatarUrl,
      email: email,
      childBirthDate: childBirthDate,
      onboardingCompleted: onboardingCompleted,
      onboardingCompletedAt: onboardingCompletedAt,
      privacyConsentAt: privacyConsentAt,
      privacyConsentVersion: privacyConsentVersion,
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class AvatarUploadResponseDto {
  const AvatarUploadResponseDto({required this.avatarUrl});

  final String avatarUrl;

  factory AvatarUploadResponseDto.fromJson(Map<String, dynamic> json) {
    return AvatarUploadResponseDto(
      avatarUrl: json['avatarUrl'] as String? ?? '',
    );
  }
}
