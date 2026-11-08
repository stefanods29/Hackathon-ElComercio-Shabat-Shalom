import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal_consola/core/network/idempotency.dart';
import 'package:vecinal_consola/core/router/routes.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/features/avisos_urgentes/data/urgent_notices_providers.dart';
import 'package:vecinal_consola/features/avisos_urgentes/domain/urgent_notices.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

String urgentTemplateText(AppLocalizations l10n, UrgentTemplate template) => switch (template) {
  UrgentTemplate.caseAssigned => l10n.urgentCaseAssigned,
  UrgentTemplate.aboutToEscalate => l10n.urgentAboutToEscalate,
  UrgentTemplate.escalated => l10n.urgentEscalated,
};

/// Unconfirmed urgent notices of this person, checked every 30 seconds while the tab is visible.
/// Confirming here (or opening the case) stops the SMS backup, like opening it in the app.
class UrgentNoticesBanner extends ConsumerStatefulWidget {
  const UrgentNoticesBanner({super.key});

  @override
  ConsumerState<UrgentNoticesBanner> createState() => _UrgentNoticesBannerState();
}

class _UrgentNoticesBannerState extends ConsumerState<UrgentNoticesBanner> {
  /// One key per notice: retrying the same confirmation is safe.
  final _keys = <String, String>{};
  final _sending = <String>{};
  String? _failed;

  Future<void> _confirm(UrgentNotice notice, {bool open = false}) async {
    if (_sending.contains(notice.id)) return;
    setState(() {
      _sending.add(notice.id);
      _failed = null;
    });
    try {
      await confirmUrgentNotice(ref, notice, _keys.putIfAbsent(notice.id, newLocalId));
      if (!mounted) return;
      final caseId = notice.caseId;
      if (open && caseId != null) context.go(Routes.caseDetail(caseId));
    } on Object {
      if (mounted) setState(() => _failed = notice.id);
    } finally {
      if (mounted) setState(() => _sending.remove(notice.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (!ref.watch(receivesUrgentNoticesProvider)) return const SizedBox.shrink();
    final notices = ref.watch(pendingUrgentNoticesProvider).value ?? const <UrgentNotice>[];
    final color = scheme.onErrorContainer;
    return PollWhileVisible(
      interval: const Duration(seconds: 30),
      onTick: () => ref.invalidate(pendingUrgentNoticesProvider),
      child: notices.isEmpty
          ? const SizedBox.shrink()
          : Semantics(
              container: true,
              liveRegion: true,
              child: Material(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notification_important_outlined, color: color),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.urgentBannerTitle(notices.length),
                              style: textTheme.titleMedium?.copyWith(color: color),
                            ),
                          ),
                        ],
                      ),
                      for (final notice in notices.take(3))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                l10n.urgentNoticeLine(
                                  urgentTemplateText(l10n, notice.template),
                                  formatClock(notice.createdAt),
                                ),
                                style: textTheme.bodyLarge?.copyWith(color: color),
                              ),
                              if (notice.caseId != null)
                                FilledButton(
                                  onPressed: _sending.contains(notice.id)
                                      ? null
                                      : () => _confirm(notice, open: true),
                                  child: Text(l10n.urgentOpenCase),
                                ),
                              OutlinedButton(
                                onPressed: _sending.contains(notice.id)
                                    ? null
                                    : () => _confirm(notice),
                                child: Text(l10n.urgentConfirm),
                              ),
                              if (_failed == notice.id)
                                Text(
                                  l10n.urgentConfirmFailed,
                                  style: textTheme.bodyMedium?.copyWith(color: color),
                                ),
                            ],
                          ),
                        ),
                      if (notices.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l10n.urgentMore(notices.length - 3),
                            style: textTheme.bodyMedium?.copyWith(color: color),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
