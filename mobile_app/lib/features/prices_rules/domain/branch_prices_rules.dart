class BranchPricesRules {
  const BranchPricesRules({
    required this.branchId,
    required this.introTitle,
    required this.introDescription,
    required this.visitTariffs,
    required this.rules,
    required this.birthdayNote,
    this.disclaimer,
  });

  final String branchId;
  final String introTitle;
  final String introDescription;
  final List<VisitTariff> visitTariffs;
  final List<String> rules;
  final String birthdayNote;
  final String? disclaimer;
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
