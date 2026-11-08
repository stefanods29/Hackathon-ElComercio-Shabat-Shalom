import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/core/ui/problem_notice.dart';
import 'package:vecinal_consola/features/avisos_urgentes/data/urgent_notices_providers.dart';
import 'package:vecinal_consola/features/avisos_urgentes/domain/urgent_notices.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Measurement of urgent notices: confirmations, latency, SMS backup and spending against caps.
class UrgentNoticesPage extends ConsumerWidget {
  const UrgentNoticesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(urgentSummaryProvider);
    final days = ref.watch(summaryDaysProvider);
    return ConsolePage(
      title: l10n.urgentSummaryTitle,
      subtitle: l10n.urgentSummarySubtitle,
      actions: [
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(urgentSummaryProvider),
          icon: const Icon(Icons.refresh),
          label: Text(l10n.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          ChoiceRow<int>(
            label: l10n.urgentPeriod,
            options: const [1, 7, 30],
            selected: days,
            labelOf: (value) => l10n.urgentPeriodDays(value),
            onSelected: (value) => ref.read(summaryDaysProvider.notifier).select(value),
          ),
          const SizedBox(height: 16),
          summary.when(
            loading: () => const LoadingIndicator(),
            error: (error, _) =>
                ProblemNotice(error: error, onRetry: () => ref.invalidate(urgentSummaryProvider)),
            data: (data) => _Summary(summary: data),
          ),
        ],
      ),
    );
  }
}

String _money(int cents) => 'US\$ ${(cents / 100).toStringAsFixed(2)}';

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final UrgentNoticeSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final p50 = summary.confirmationP50Seconds;
    final p95 = summary.confirmationP95Seconds;
    final provider = switch (summary.smsProvider) {
      'none' => l10n.urgentProviderNone,
      'fake' => l10n.urgentProviderFake,
      final other => other,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.urgentRange(formatDayAndClock(summary.since), formatDayAndClock(summary.until)),
          style: textTheme.bodyMedium,
        ),
        SectionHeading(l10n.urgentNoticesHeading),
        LabeledValue(label: l10n.urgentTotal, value: '${summary.total}'),
        LabeledValue(label: l10n.urgentConfirmed, value: '${summary.confirmed}'),
        LabeledValue(label: l10n.urgentUnconfirmed, value: '${summary.unconfirmed}'),
        LabeledValue(
          label: l10n.urgentLatency,
          value: p50 == null || p95 == null
              ? l10n.urgentLatencyNone
              : l10n.urgentLatencyValue(p50, p95),
        ),
        SectionHeading(l10n.urgentSmsHeading),
        LabeledValue(label: l10n.urgentProvider, value: provider),
        LabeledValue(label: l10n.urgentSmsSent, value: '${summary.smsSent}'),
        LabeledValue(
          label: l10n.urgentWithoutBackup,
          value: l10n.urgentWithoutBackupValue(
            summary.withoutBackup['tope_de_gasto'] ?? 0,
            summary.withoutBackup['sin_proveedor'] ?? 0,
            summary.withoutBackup['sin_telefono'] ?? 0,
            summary.withoutBackup['sms_fallido'] ?? 0,
          ),
        ),
        LabeledValue(
          label: l10n.urgentSpendingToday,
          value: l10n.urgentSpendingOf(_money(summary.todayCents), _money(summary.dailyCapCents)),
        ),
        LabeledValue(
          label: l10n.urgentSpendingMonth,
          value: l10n.urgentSpendingOf(_money(summary.monthCents), _money(summary.monthlyCapCents)),
        ),
      ],
    );
  }
}
