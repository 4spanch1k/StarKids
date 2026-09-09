import 'branch_ticket_config.dart';

abstract interface class TicketConfigRepository {
  Future<BranchTicketConfig> getForBranch(String branchId);
}
