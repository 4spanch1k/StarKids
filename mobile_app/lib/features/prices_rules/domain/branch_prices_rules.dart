class BranchPricesRules {
  const BranchPricesRules({
    required this.branchId,
    required this.introTitle,
    required this.introDescription,
    required this.visitTariffs,
    required this.rules,
    required this.birthdayNote,
    this.disclaimer,
    this.menuSections = const [],
  });

  final String branchId;
  final String introTitle;
  final String introDescription;
  final List<VisitTariff> visitTariffs;
  final List<String> rules;
  final String birthdayNote;
  final String? disclaimer;
  final List<MenuSection> menuSections;

  BranchPricesRules copyWith({
    String? branchId,
    String? introTitle,
    String? introDescription,
    List<VisitTariff>? visitTariffs,
    List<String>? rules,
    String? birthdayNote,
    String? disclaimer,
    List<MenuSection>? menuSections,
  }) {
    return BranchPricesRules(
      branchId: branchId ?? this.branchId,
      introTitle: introTitle ?? this.introTitle,
      introDescription: introDescription ?? this.introDescription,
      visitTariffs: visitTariffs ?? this.visitTariffs,
      rules: rules ?? this.rules,
      birthdayNote: birthdayNote ?? this.birthdayNote,
      disclaimer: disclaimer ?? this.disclaimer,
      menuSections: menuSections ?? this.menuSections,
    );
  }
}

class VisitTariff {
  const VisitTariff({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.description,
  });

  final String id;
  final String title;
  final String priceLabel;
  final String description;
}

class MenuSection {
  const MenuSection({
    required this.id,
    required this.title,
    required this.items,
    this.subtitle,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final List<MenuItem> items;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.title,
    required this.priceLabel,
  });

  final String id;
  final String title;
  final String priceLabel;
}
