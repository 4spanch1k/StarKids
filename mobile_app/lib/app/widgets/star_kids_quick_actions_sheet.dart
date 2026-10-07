import 'package:flutter/material.dart';

import '../router/app_routes.dart';
import '../../core/design_system/sk_design_tokens.dart';
import '../../core/design_system/widgets/glass_bottom_sheet.dart';
import '../../features/requests/domain/request_type.dart';
import '../../features/requests/presentation/models/request_page_args.dart';
import '../../features/tickets/presentation/sheets/ticket_purchase_flow_sheet.dart';

enum _QuickAction { customerQr, tickets, buyTicket, birthday }

Future<void> showStarKidsQuickActionsSheet(BuildContext context) async {
  final action = await showGlassBottomSheet<_QuickAction>(
    context: context,
    title: 'Быстрые действия',
    initialSize: 0.55,
    minSize: 0.42,
    builder: (sheetContext, _) => const _QuickActionsList(),
  );
  if (!context.mounted || action == null) return;

  switch (action) {
    case _QuickAction.customerQr:
      await Navigator.of(context).pushNamed(AppRoutes.customerQr);
    case _QuickAction.tickets:
      await Navigator.of(context).pushNamed(AppRoutes.tickets);
    case _QuickAction.buyTicket:
      await showTicketPurchaseFlowSheet(context);
    case _QuickAction.birthday:
      await Navigator.of(context).pushNamed(
        AppRoutes.requests,
        arguments: const RequestPageArgs(
          initialType: RequestType.birthdayRequest,
        ),
      );
  }
}

class _QuickActionsList extends StatelessWidget {
  const _QuickActionsList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SKSpacing.x4,
        SKSpacing.x2,
        SKSpacing.x4,
        SKSpacing.x8,
      ),
      child: Column(
        children: [
          _QuickActionTile(
            icon: Icons.qr_code_2_rounded,
            title: 'Мой QR',
            subtitle: 'Идентифицировать аккаунт у сотрудника',
            onTap: () => Navigator.of(context).pop(_QuickAction.customerQr),
          ),
          _QuickActionTile(
            icon: Icons.confirmation_num_rounded,
            title: 'Мои билеты',
            subtitle: 'Открыть билеты и абонементы',
            onTap: () => Navigator.of(context).pop(_QuickAction.tickets),
          ),
          _QuickActionTile(
            icon: Icons.shopping_bag_rounded,
            title: 'Купить входной билет',
            subtitle: 'Выбрать дату и оформить вход',
            onTap: () => Navigator.of(context).pop(_QuickAction.buyTicket),
          ),
          _QuickActionTile(
            icon: Icons.cake_rounded,
            title: 'Забронировать день рождения',
            subtitle: 'Оставить заявку менеджеру',
            onTap: () => Navigator.of(context).pop(_QuickAction.birthday),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: SKSpacing.x1),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
