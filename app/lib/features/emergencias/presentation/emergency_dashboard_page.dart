import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/mode/app_mode.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/image_policy.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_ui.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_widgets.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Emergency home (review of 9 November 2026, section 5.2): the calls on top, one primary action,
/// four secondary accesses and the rest in one line each, so it fits in one screen.
class EmergencyDashboardPage extends ConsumerWidget {
  const EmergencyDashboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scope = ref.watch(emergencyScopeProvider);
    final snapshot = ref.watch(emergencySnapshotProvider);
    final data = snapshot.value;
    final available = scope != null && data?.coverageVerified == true;
    final online = ref.watch(syncStatusProvider).value?.connected == true;
    final repository = ref.watch(emergencyRepositoryProvider);
    final practice = repository is PracticeEmergencyRepository ? repository : null;
    final eventActive = data?.activeEvent == true;
    final now = ref.watch(clockProvider)();
    final policy = ref.watch(resourceFreshnessPolicyProvider);
    final fresh = (data?.resources ?? const <CriticalResource>[])
        .where((resource) => !policy.isStale(resource, now))
        .length;
    final mode = ref.watch(appModeProvider);
    final canExit = mode != AppMode.normal || (eventActive && practice != null);
    return EmergencyLayout(
      title: t.emergencyDashboard,
      gap: 14,
      practiceActions: [
        if (practice != null) ...[
          PracticeAction(
            icon: eventActive ? Icons.stop_circle_outlined : Icons.warning_amber_rounded,
            label: eventActive ? t.simulationEventOff : t.simulationEventOn,
            onSelected: () => practice.simulateEvent(active: !eventActive),
          ),
          PracticeAction(
            icon: Icons.water_drop_outlined,
            label: t.simulationResource,
            onSelected: practice.simulateResource,
          ),
        ],
      ],
      children: [
        const EmergencyAlternatives(),
        if (snapshot.isLoading) const LinearProgressIndicator(),
        if (scope?.practice != true && !online)
          EmergencyNotice(icon: Icons.cloud_off_outlined, text: t.emergencyOfflineWarning)
        else if (data?.updatedAt != null)
          _StatusLine(online: online, ago: timeAgo(data!.updatedAt!, now, t)),
        if (!available)
          EmergencyNotice(icon: Icons.info_outline, text: t.emergencyNoCoverage, liveRegion: true),
        if (snapshot.hasError)
          EmergencyNotice(
            icon: Icons.sync_problem_outlined,
            text: t.emergencyCoordinationUnavailable,
          ),
        if (scope != null)
          for (final request in data?.requests ?? const <OwnHelpRequest>[])
            EmergencyRequestCard(request: request, now: now),
        EmergencyPrimaryButton(
          icon: Icons.sos,
          label: t.emergencyNeedHelp,
          subtitle: t.emergencyNeedHelpSubtitle,
          onPressed: available ? () => context.push(Routes.emergencyNeeds) : null,
        ),
        EmergencyTileGrid(
          children: [
            EmergencyActionTile(
              icon: Icons.volunteer_activism_outlined,
              label: t.emergencyCanHelp,
              onPressed: available ? () => context.push(Routes.emergencyOffer) : null,
            ),
            EmergencyActionTile(
              icon: Icons.water_drop_outlined,
              label: t.emergencyResources,
              badge: available && fresh > 0 ? t.emergencyResourcesFresh(fresh) : null,
              onPressed: available ? () => context.push(Routes.emergencyResources) : null,
            ),
            EmergencyActionTile(
              icon: Icons.local_phone_outlined,
              label: t.emergencyTitle,
              onPressed: () => context.push(Routes.emergency),
            ),
            if (scope != null)
              EmergencyActionTile(
                icon: Icons.contact_phone_outlined,
                label: t.emergencyContacts,
                onPressed: () => context.push(Routes.emergencyContacts),
              ),
          ],
        ),
        const _DataSaverRow(),
        if (canExit)
          OutlinedButton.icon(
            icon: const Icon(Icons.home_outlined),
            label: Text(t.emergencyExitLocalMode),
            onPressed: () {
              practice?.simulateEvent(active: false);
              final controller = ref.read(appModeProvider.notifier);
              switch (ref.read(appModeProvider)) {
                case AppMode.emergency:
                  controller.endEvent();
                  controller.closeRecovery();
                case AppMode.recovery:
                  controller.closeRecovery();
                case AppMode.normal:
                  break;
              }
            },
          ),
        Text(
          t.connectsNeighbors,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// "Con conexión · actualizado hace un momento": the freshness of what is on screen in one line.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.online, required this.ago});
  final bool online;
  final String ago;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final updated = t.updatedAgo(ago);
    final text = online
        ? '${t.emergencyConnected} · ${updated[0].toLowerCase()}${updated.substring(1)}'
        : updated;
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            online ? Icons.cloud_done_outlined : Icons.history,
            color: scheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

/// One own request on the dashboard: its need and its real state, one tap from "Mi pedido".
class EmergencyRequestCard extends StatelessWidget {
  const EmergencyRequestCard({super.key, required this.request, required this.now});
  final OwnHelpRequest request;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: () => context.push('/emergencia/pedidos/${request.id}'),
      style: emergencyCardStyle(
        scheme,
        minimumSize: const Size(48, 76),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          EmergencyIconBadge(icon: needIcon(request.need)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.emergencyMyRequestOf(needLabel(t, request.need).toLowerCase()),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  t.emergencyRequestSince(
                    requestStatusLabel(t, request.status),
                    timeAgo(request.updatedAt, now, t),
                  ),
                  style: TextStyle(
                    color: requestStatusColor(scheme, request.status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

/// Text color of a request state on a card: amber while it was not sent, navy while it waits,
/// teal once someone acts, neutral when it closed.
Color requestStatusColor(ColorScheme scheme, HelpRequestStatus status) {
  final light = scheme.brightness == Brightness.light;
  return switch (status) {
    HelpRequestStatus.local => light ? scheme.onTertiaryContainer : scheme.tertiary,
    HelpRequestStatus.sent || HelpRequestStatus.seen => scheme.secondary,
    HelpRequestStatus.onTheWay || HelpRequestStatus.attended => scheme.primary,
    HelpRequestStatus.referred || HelpRequestStatus.closedUnattended => scheme.onSurfaceVariant,
  };
}

/// "Ahorro de datos" in one row. In emergency mode images stay off, and the switch says why.
class _DataSaverRow extends ConsumerWidget {
  const _DataSaverRow();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final saving = !ref.watch(imagesEnabledProvider);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile.adaptive(
        secondary: const Icon(Icons.data_saver_on_outlined),
        title: Text(t.emergencyDataSaver, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(saving ? t.emergencyDataSaverOn : t.emergencyDataSaverOff),
        value: saving,
        onChanged: (save) {
          ref.read(imagesEnabledProvider.notifier).set(!save);
          if (!save && ref.read(emergencyHomeProvider)) {
            emergencyMessage(context, t.emergencyImagesLocked);
          }
        },
      ),
    );
  }
}
