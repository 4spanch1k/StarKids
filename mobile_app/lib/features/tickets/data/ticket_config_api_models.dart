import '../domain/branch_ticket_config.dart';

class BranchTicketConfigDto {
  const BranchTicketConfigDto({
    required this.branchId,
    required this.items,
    required this.notes,
  });

  final String branchId;
  final List<TicketConfigItemDto> items;
  final List<String> notes;

  factory BranchTicketConfigDto.fromJson(Map<String, dynamic> json) {
    return BranchTicketConfigDto(
      branchId: json['branch_id'] as String,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TicketConfigItemDto.fromJson)
          .toList(),
      notes: (json['notes'] as List<dynamic>? ?? const [])
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }

  BranchTicketConfig toDomain() {
    return BranchTicketConfig(
      branchId: branchId,
      items: items.map((item) => item.toDomain()).toList(),
      notes: notes,
    );
  }
}

class TicketConfigItemDto {
  const TicketConfigItemDto({
    required this.id,
    required this.title,
    required this.description,
    required this.priceTenge,
    required this.badgeLabels,
  });

  final String id;
  final String title;
  final String description;
  final int priceTenge;
  final List<String> badgeLabels;

  factory TicketConfigItemDto.fromJson(Map<String, dynamic> json) {
    return TicketConfigItemDto(
      id: json['id'] as String,
      title: json['title'] as String,
      description: (json['description'] as String? ?? '').trim(),
      priceTenge: json['price_tenge'] as int? ?? 0,
      badgeLabels: (json['badge_labels'] as List<dynamic>? ?? const [])
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }

  TicketConfigItem toDomain() {
    return TicketConfigItem(
      id: id,
      title: title,
      priceTenge: priceTenge,
      description: description,
      badgeLabels: badgeLabels,
    );
  }
}
