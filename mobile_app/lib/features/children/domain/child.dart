enum ChildGender { male, female }

class Child {
  const Child({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final ChildGender gender;

  bool get isBirthdayToday {
    final now = DateTime.now();
    return birthDate.month == now.month && birthDate.day == now.day;
  }

  int get ageYears {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
