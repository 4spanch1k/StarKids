import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/sk_design_tokens.dart';
import '../../../../core/design_system/sk_theme.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../../core/design_system/widgets/primary_button.dart';
import '../../../request_history/domain/request_history_item.dart';
import '../../../requests/domain/request_status.dart';
import '../../../requests/domain/request_type.dart';

const _activeBirthdayStatuses = <RequestStatus>{
  RequestStatus.newRequest,
  RequestStatus.contacted,
  RequestStatus.inProgress,
  RequestStatus.confirmed,
};

/// Selects the one lead suitable for the Home summary.
///
/// Requested date is the primary business ordering. Missing dates (possible
/// on legacy records) are placed after dated records, then the newest request
/// wins, and the id is the final deterministic tie-breaker.
RequestHistoryItem? selectActiveBirthdayLead(
  Iterable<RequestHistoryItem> items,
) {
  final candidates = items
      .where(
        (item) =>
            item.type == RequestType.birthdayRequest &&
            _activeBirthdayStatuses.contains(item.status),
      )
      .toList(growable: false);
  if (candidates.isEmpty) return null;

  final sorted = [...candidates]..sort(_compareBirthdayLeads);
  return sorted.first;
}

int _compareBirthdayLeads(RequestHistoryItem a, RequestHistoryItem b) {
  final aDate = a.requestedDate;
  final bDate = b.requestedDate;
  if (aDate == null && bDate != null) return 1;
  if (aDate != null && bDate == null) return -1;
  if (aDate != null && bDate != null) {
    final dateComparison = _dateOnly(aDate).compareTo(_dateOnly(bDate));
    if (dateComparison != 0) return dateComparison;
  }

  final createdComparison = b.createdAt.compareTo(a.createdAt);
  if (createdComparison != 0) return createdComparison;
  return a.id.compareTo(b.id);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class HomeBirthdayLeadCard extends StatelessWidget {
  const HomeBirthdayLeadCard({
    super.key,
    required this.item,
    required this.onOpen,
  });

  final RequestHistoryItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = SKTheme.of(context).colors;
    final locale = Localizations.localeOf(context).languageCode;
    final details = <String>[];
    final childName = item.childName?.trim();
    if (childName != null && childName.isNotEmpty) details.add(childName);
    if (item.requestedDate != null) {
      details.add(DateFormat('d MMMM', locale).format(item.requestedDate!));
    }

    return SolidCard(
      key: const ValueKey('home-active-birthday-lead'),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(SKSpacing.x2),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(SKRadius.sm),
                ),
                child: Icon(Icons.cake_outlined, color: colors.accent),
              ),
              const SizedBox(width: SKSpacing.x3),
              Expanded(
                child: Text(
                  'Заявка на праздник',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: SKSpacing.x2),
            Text(
              details.join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (item.package != null && item.package!.name.trim().isNotEmpty) ...[
            const SizedBox(height: SKSpacing.x1),
            Text(
              item.package!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: SKSpacing.x2),
          Text(
            item.status.userFacingLabel,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: SKSpacing.x3),
          SecondaryButton(
            label: 'Открыть заявку',
            icon: Icons.arrow_forward_rounded,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
