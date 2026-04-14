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
  });

  final String id;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? email;
  final DateTime? childBirthDate;

  factory UserProfileDto.fromJson(Map<String, dynamic> json) {
    return UserProfileDto(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      email: json['email'] as String?,
      childBirthDate: _parseDate(json['childBirthDate'] as String?),
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
