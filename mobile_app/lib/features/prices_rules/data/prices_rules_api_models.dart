import '../domain/branch_prices_rules.dart';

class BranchPricesRulesDto {
  const BranchPricesRulesDto({
    required this.branchId,
    required this.introTitle,
    required this.introDescription,
    required this.visitTariffs,
    required this.rules,
    required this.birthdayNote,
    required this.disclaimer,
  });

  final String branchId;
  final String introTitle;
  final String introDescription;
  final List<VisitTariffDto> visitTariffs;
  final List<String> rules;
  final String birthdayNote;
  final String? disclaimer;

  factory BranchPricesRulesDto.fromJson(Map<String, dynamic> json) {
    return BranchPricesRulesDto(
      branchId: json['branch_id'] as String,
      introTitle: json['intro_title'] as String,
      introDescription: json['intro_description'] as String,
      visitTariffs: (json['visit_tariffs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VisitTariffDto.fromJson)
          .toList(),
      rules: (json['rules'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
      birthdayNote: json['birthday_note'] as String,
      disclaimer: json['disclaimer'] as String?,
    );
  }

  BranchPricesRules toDomain() {
    return BranchPricesRules(
      branchId: branchId,
      introTitle: introTitle,
      introDescription: introDescription,
      visitTariffs: visitTariffs.map((item) => item.toDomain()).toList(),
      rules: rules,
      birthdayNote: birthdayNote,
      disclaimer: disclaimer,
      menuSections: const [],
      birthdayPackages: const [],
    );
  }
}

class VisitTariffDto {
  const VisitTariffDto({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.description,
  });

  final String id;
  final String title;
  final String priceLabel;
  final String description;

  factory VisitTariffDto.fromJson(Map<String, dynamic> json) {
    return VisitTariffDto(
      id: json['id'] as String,
      title: json['title'] as String,
      priceLabel: json['price_label'] as String,
      description: json['description'] as String,
    );
  }

  VisitTariff toDomain() {
    return VisitTariff(
      id: id,
      title: title,
      priceLabel: priceLabel,
      description: description,
    );
  }
}
