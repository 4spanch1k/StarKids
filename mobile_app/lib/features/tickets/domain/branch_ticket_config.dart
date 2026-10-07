class BranchTicketConfig {
  const BranchTicketConfig({
    required this.branchId,
    required this.items,
    required this.notes,
  });

  final String branchId;
  final List<TicketConfigItem> items;
  final List<String> notes;
}

class TicketConfigItem {
  const TicketConfigItem({
    required this.id,
    required this.title,
    required this.priceTenge,
    required this.description,
    required this.badgeLabels,
  });

  final String id;
  final String title;
  final int priceTenge;
  final String description;
  final List<String> badgeLabels;
}
