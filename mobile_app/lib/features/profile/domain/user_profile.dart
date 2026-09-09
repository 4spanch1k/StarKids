class UserProfile {
  const UserProfile({
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

  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  String get fullName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isEmpty && last.isEmpty) {
      return 'Профиль Boom Bala';
    }
    return '$first $last'.trim();
  }

  String get phoneLabel {
    final p = phone ?? '';
    if (p.isEmpty) return '';
    return p;
  }

  String get initials {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';

    if (first.isNotEmpty || last.isNotEmpty) {
      final f = first.isNotEmpty ? first[0].toUpperCase() : '';
      final l = last.isNotEmpty ? last[0].toUpperCase() : '';
      return '$f$l'.isEmpty ? 'SK' : '$f$l';
    }

    final p = phone ?? '';
    if (p.length >= 2) {
      return p.substring(p.length - 2);
    }

    return 'SK';
  }

  UserProfile copyWith({
    String? id,
    String? phone,
    bool clearPhone = false,
    String? firstName,
    bool clearFirstName = false,
    String? lastName,
    bool clearLastName = false,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    String? email,
    bool clearEmail = false,
    DateTime? childBirthDate,
    bool clearChildBirthDate = false,
    bool? onboardingCompleted,
    DateTime? onboardingCompletedAt,
    DateTime? privacyConsentAt,
    String? privacyConsentVersion,
  }) {
    return UserProfile(
      id: id ?? this.id,
      phone: clearPhone ? null : phone ?? this.phone,
      firstName: clearFirstName ? null : firstName ?? this.firstName,
      lastName: clearLastName ? null : lastName ?? this.lastName,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      email: clearEmail ? null : email ?? this.email,
      childBirthDate:
          clearChildBirthDate ? null : childBirthDate ?? this.childBirthDate,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      privacyConsentAt: privacyConsentAt ?? this.privacyConsentAt,
      privacyConsentVersion:
          privacyConsentVersion ?? this.privacyConsentVersion,
    );
  }
}
