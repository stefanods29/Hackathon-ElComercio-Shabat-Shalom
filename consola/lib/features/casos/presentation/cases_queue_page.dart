import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal_consola/core/router/routes.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/features/casos/data/cases_providers.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';
import 'package:vecinal_consola/features/casos/presentation/case_labels.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Queue of the zone by priority and time without review, reloaded every 15 seconds while the
/// tab is visible. A brigadist sees the cases assigned to them.
class CasesQueuePage extends ConsumerWidget {
  const CasesQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentOperatorProvider);
    if (user == null) return const SizedBox.shrink();
    final title = user.coordinates ? l10n.casesTitle : l10n.myCasesTitle;
    if (ref.watch(casesRepositoryProvider) == null) {
      return ConsolePage(title: title, child: ModuleUnavailable(message: l10n.casesUnavailable));
    }
    if (user.zoneId == null) {
      return ConsolePage(
        title: title,
        child: CenteredMessage(
          child: InfoCard(icon: Icons.map_outlined, title: l10n.noZoneTitle, body: l10n.noZoneBody),
        ),
      );
    }
    final queue = ref.watch(caseQueueProvider);
    final latest = queue.value;
    return PollWhileVisible(
      interval: queueRefreshInterval,
      onTick: () => ref.invalidate(caseQueueProvider),
      child: ConsolePage(
        title: title,
        subtitle: latest == null ? null : l10n.updatedAtEvery(formatClock(latest.fetchedAt), 15),
        actions: [
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(caseQueueProvider),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.refresh),
          ),
        ],
        child: AsyncBody(
          value: queue,
          onRetry: () => ref.invalidate(caseQueueProvider),
          data: (snapshot) => _QueueList(
            cases: snapshot.cases,
            now: ref.read(clockProvider)(),
            policy: ref.watch(reviewPolicyProvider),
          ),
        ),
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({required this.cases, required this.now, required this.policy});

  final List<EmergencyCase> cases;
  final DateTime now;
  final ReviewPolicy policy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = <CasePriority, List<EmergencyCase>>{};
    for (final item in cases) {
      groups.putIfAbsent(item.priority, () => []).add(item);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        InfoCard(icon: Icons.emergency_outlined, title: l10n.lifeRiskReminder),
        if (cases.isEmpty) ...[
          const SizedBox(height: 16),
          InfoCard(icon: Icons.inbox_outlined, title: l10n.casesEmpty),
        ],
        for (final priority in CasePriority.values)
          if (groups[priority] case final group?) ...[
            SectionHeading(l10n.priorityGroup(priorityLabel(l10n, priority), group.length)),
            for (final item in group)
              _CaseCard(item: item, clock: reviewClockOf(item, now, policy)),
          ],
      ],
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.item, required this.clock});

  final EmergencyCase item;
  final ReviewClock? clock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final badge = reviewBadge(l10n, clock);
    final assignee = item.assignee;
    return FocusableCard(
      onTap: () => context.go(Routes.caseDetail(item.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.caseCardTitle(needLabel(l10n, item.need), statusLabel(l10n, item.status)),
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(icon: Icons.flag_outlined, label: priorityLabel(l10n, item.priority)),
              ?badge,
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.caseCell(item.cellLabel), style: textTheme.bodyLarge),
          Text(reviewText(l10n, clock), style: textTheme.bodyLarge),
          if (assignee != null)
            Text(
              l10n.caseAssignedTo(assignee.displayName, assigneeKindLabel(l10n, assignee.kind)),
              style: textTheme.bodyLarge,
            ),
        ],
      ),
    );
  }
}
