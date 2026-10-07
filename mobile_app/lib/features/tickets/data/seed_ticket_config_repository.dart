import '../domain/branch_ticket_config.dart';
import '../domain/ticket_config_repository.dart';

class SeedTicketConfigRepository implements TicketConfigRepository {
  const SeedTicketConfigRepository({this.config = defaultBranchTicketConfig});

  final BranchTicketConfig config;

  @override
  Future<BranchTicketConfig> getForBranch(String branchId) async {
    return BranchTicketConfig(
      branchId: branchId,
      items: config.items,
      notes: config.notes,
    );
  }
}

const defaultBranchTicketConfig = BranchTicketConfig(
  branchId: 'seed-branch',
  items: [
    TicketConfigItem(
      id: 'kids_1_3',
      title: 'Детские билеты 1–3 лет',
      priceTenge: 2700,
      description: 'Документ обязателен',
      badgeLabels: [],
    ),
    TicketConfigItem(
      id: 'kids_4_15',
      title: 'Детские билеты 4–15 лет',
      priceTenge: 3700,
      description: '',
      badgeLabels: [],
    ),
    TicketConfigItem(
      id: 'adult',
      title: 'Взрослый билет (сопровождающий)',
      priceTenge: 400,
      description: '',
      badgeLabels: ['Для сопровождающего'],
    ),
  ],
  notes: [
    'Детям 0–1 лет — бесплатно',
    'Имениннику в день рождения — бесплатно',
    'Особенным детям — бесплатно',
  ],
);
