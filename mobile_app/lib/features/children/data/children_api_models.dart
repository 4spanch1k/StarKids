import '../domain/child.dart';

class ChildDto {
  const ChildDto({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final ChildGender gender;

  factory ChildDto.fromJson(Map<String, dynamic> json) {
    return ChildDto(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      birthDate: _parseDate(json['birthDate'] as String?),
      gender: _parseGender(json['gender'] as String?),
    );
  }

  Child toDomain() => Child(
        id: id,
        name: name,
        birthDate: birthDate,
        gender: gender,
      );

  static DateTime _parseDate(String? value) {
    if (value == null || value.isEmpty) return DateTime(2000);
    return DateTime.tryParse(value) ?? DateTime(2000);
  }

  static ChildGender _parseGender(String? value) {
    return value == 'female' ? ChildGender.female : ChildGender.male;
  }
}

class ChildListDto {
  const ChildListDto({required this.items});

  final List<ChildDto> items;

  factory ChildListDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return ChildListDto(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(ChildDto.fromJson)
          .toList(),
    );
  }

  List<Child> toDomain() => items.map((d) => d.toDomain()).toList();
}
