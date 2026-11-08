import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal_consola/core/network/idempotency.dart';
import 'package:vecinal_consola/core/router/routes.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/features/casos/data/cases_providers.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';
import 'package:vecinal_consola/features/casos/presentation/case_action_dialog.dart';
import 'package:vecinal_consola/features/casos/presentation/case_labels.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Minimized detail: only what is needed to decide, the audited history and the actions of
/// section 7.2. The exact point appears only for the assignee while on the way.
class CaseDetailPage extends ConsumerWidget {
  const CaseDetailPage({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentOperatorProvider);
    if (user == null) return const SizedBox.shrink();
    final back = TextButton.icon(
      onPressed: () => context.go(Routes.cases),
      icon: const Icon(Icons.arrow_back),
      label: Text(l10n.backToQueue),
    );
    if (!isUuid(caseId)) {
      return ConsolePage(
        title: l10n.caseDetailTitle,
        actions: [back],
        child: CenteredMessage(
          child: InfoCard(
            icon: Icons.search_off,
            title: l10n.notFoundTitle,
            body: l10n.notFoundBody,
          ),
        ),
      );
    }
    if (ref.watch(casesRepositoryProvider) == null) {
      return ConsolePage(
        title: l10n.caseDetailTitle,
        actions: [back],
        child: ModuleUnavailable(message: l10n.casesUnavailable),
      );
    }
    final detail = ref.watch(caseDetailProvider(caseId));
    final shown = detail.value;
    return PollWhileVisible(
      interval: queueRefreshInterval,
      onTick: () => ref.invalidate(caseDetailProvider(caseId)),
      child: ConsolePage(
        title: shown == null
            ? l10n.caseDetailTitle
            : l10n.caseDetailTitleWithNeed(needLabel(l10n, shown.need)),
        subtitle: shown == null ? null : l10n.caseUpdatedAt(formatDayAndClock(shown.updatedAt)),
        actions: [
          back,
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(caseDetailProvider(caseId)),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.reloadCase),
          ),
        ],
        child: AsyncBody(
          value: detail,
          onRetry: () => ref.invalidate(caseDetailProvider(caseId)),
          data: (item) => _CaseDetailBody(item: item, viewer: user),
        ),
      ),
    );
  }
}

class _CaseDetailBody extends ConsumerWidget {
  const _CaseDetailBody({required this.item, required this.viewer});

  final EmergencyCase item;
  final Operator viewer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final clock = reviewClockOf(item, ref.read(clockProvider)(), ref.watch(reviewPolicyProvider));
    final badge = reviewBadge(l10n, clock);
    final assignee = item.assignee;
    final actions = viewer.coordinates ? actionsFrom(item.status) : const <CaseAction>{};
    final location = item.exactLocation;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusBadge(icon: Icons.info_outline, label: statusLabel(l10n, item.status)),
            StatusBadge(icon: Icons.flag_outlined, label: priorityLabel(l10n, item.priority)),
            ?badge,
          ],
        ),
        SectionHeading(l10n.caseDataTitle),
        LabeledValue(label: l10n.caseNeedLabel, value: needLabel(l10n, item.need)),
        LabeledValue(label: l10n.casePriorityLabel, value: priorityLabel(l10n, item.priority)),
        LabeledValue(label: l10n.caseCellLabel, value: item.cellLabel),
        LabeledValue(label: l10n.caseCreatedLabel, value: formatDayAndClock(item.createdAt)),
        LabeledValue(label: l10n.caseReviewLabel, value: reviewText(l10n, clock)),
        LabeledValue(
          label: l10n.caseAssigneeLabel,
          value: assignee == null
              ? l10n.caseNobodyAssigned
              : l10n.caseAssignedTo(assignee.displayName, assigneeKindLabel(l10n, assignee.kind)),
        ),
        SectionHeading(l10n.caseLocationTitle),
        if (showsExactLocation(item, viewer.id) && location != null)
          LabeledValue(
            label: l10n.caseExactLocationLabel,
            value: l10n.caseExactLocationValue(
              location.lat.toStringAsFixed(5),
              location.lng.toStringAsFixed(5),
            ),
          )
        else
          Text(l10n.caseExactLocationHidden, style: textTheme.bodyLarge),
        if (viewer.coordinates) ...[
          SectionHeading(l10n.caseActionsTitle),
          if (actions.isEmpty)
            Text(l10n.caseNoActions, style: textTheme.bodyLarge)
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final action in CaseAction.values)
                  if (actions.contains(action))
                    FilledButton.icon(
                      onPressed: () => showCaseActionDialog(context, seen: item, action: action),
                      icon: Icon(actionIcon(action)),
                      label: Text(actionLabel(l10n, action)),
                    ),
              ],
            ),
        ],
        SectionHeading(l10n.caseHistoryTitle),
        if (item.history.isEmpty)
          Text(l10n.caseHistoryEmpty, style: textTheme.bodyLarge)
        else
          for (final entry in item.history.reversed) _HistoryEntry(entry: entry),
      ],
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry});

  final CaseHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final from = entry.from;
    final change = from == null
        ? statusLabel(l10n, entry.to)
        : l10n.historyChange(statusLabel(l10n, from), statusLabel(l10n, entry.to));
    final reason = entry.reason;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.history, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(change, style: textTheme.titleSmall),
                  Text(
                    l10n.historyWhenAndWho(
                      formatDayAndClock(entry.at),
                      roleCodeLabel(l10n, entry.role),
                    ),
                    style: textTheme.bodyMedium,
                  ),
                  if (reason != null && reason.isNotEmpty)
                    Text(l10n.historyReason(reason), style: textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
