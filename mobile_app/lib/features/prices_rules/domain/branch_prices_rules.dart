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
    this.birthdayPackages = const [],
  });

  final String branchId;
  final String introTitle;
  final String introDescription;
  final List<VisitTariff> visitTariffs;
  final List<String> rules;
  final String birthdayNote;
  final String? disclaimer;
  final List<MenuSection> menuSections;
  final List<BirthdayPackageOffer> birthdayPackages;

  BranchPricesRules copyWith({
    String? branchId,
    String? introTitle,
    String? introDescription,
    List<VisitTariff>? visitTariffs,
    List<String>? rules,
    String? birthdayNote,
    String? disclaimer,
    List<MenuSection>? menuSections,
    List<BirthdayPackageOffer>? birthdayPackages,
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
      birthdayPackages: birthdayPackages ?? this.birthdayPackages,
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
    this.imageUrl,
  });

  final String id;
  final String title;
  final String priceLabel;
  final String? imageUrl;
}

class BirthdayPackageOffer {
  const BirthdayPackageOffer({
    required this.id,
    required this.title,
    required this.badgeLabel,
    required this.subtitle,
    required this.oldPriceLabel,
    required this.weekdayPriceLabel,
    required this.imagePath,
    required this.features,
  });

  final String id;
  final String title;
  final String badgeLabel;
  final String subtitle;
  final String oldPriceLabel;
  final String weekdayPriceLabel;
  final String imagePath;
  final List<BirthdayPackageFeature> features;
}

class BirthdayPackageFeature {
  const BirthdayPackageFeature({
    required this.title,
    this.details,
  });

  final String title;
  final String? details;
}
