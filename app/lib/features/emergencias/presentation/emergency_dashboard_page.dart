import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/mode/app_mode.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/image_policy.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_widgets.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class EmergencyDashboardPage extends ConsumerWidget {
  const EmergencyDashboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scope = ref.watch(emergencyScopeProvider);
    final snapshot = ref.watch(emergencySnapshotProvider);
    final data = snapshot.value;
    final available = scope != null && data?.coverageVerified == true;
    final sync = ref.watch(syncStatusProvider).value;
    return EmergencyLayout(
      title: t.emergencyDashboard,
      children: [
        // Always a visible way back: local mode, or the practice event the neighbor simulated.
        if (ref.watch(appModeProvider) == AppMode.emergency ||
            (data?.activeEvent == true &&
                ref.watch(emergencyRepositoryProvider) is PracticeEmergencyRepository))
          FilledButton.tonalIcon(
            icon: const Icon(Icons.home_outlined),
            label: Text(t.emergencyExitLocalMode),
            onPressed: () {
              if (ref.read(emergencyRepositoryProvider) case final PracticeEmergencyRepository p) {
                p.simulateEvent(active: false);
              }
              final mode = ref.read(appModeProvider.notifier);
              mode.endEvent();
              mode.closeRecovery();
            },
          ),
        Text(t.connectsNeighbors),
        if (scope?.practice == true) Text(t.emergencyPracticeHelp),
        if (ref.watch(emergencyRepositoryProvider) case final PracticeEmergencyRepository practice)
          _SimulationPanel(practice: practice, eventActive: data?.activeEvent == true),
        if (!ref.watch(emergencyHomeProvider))
          LargeButton(
            icon: Icons.emergency_outlined,
            label: t.activateLocalEmergency,
            onPressed: () => ref.read(appModeProvider.notifier).activateEmergency(),
          ),
        Text(t.emergencyLocalModeHelp),
        if (!available) Semantics(liveRegion: true, child: Text(t.emergencyNoCoverage)),
        if (snapshot.isLoading) const LinearProgressIndicator(),
        if (snapshot.hasError) Text(t.emergencyCoordinationUnavailable),
        if (data?.updatedAt != null)
          Text(t.updatedAgo(timeAgo(data!.updatedAt!, ref.watch(clockProvider)(), t))),
        if (scope?.practice != true && sync?.connected != true) Text(t.emergencyOfflineWarning),
        LargeButton(
          icon: Icons.sos_outlined,
          label: t.emergencyNeedHelp,
          onPressed: available ? () => context.push(Routes.emergencyNeeds) : null,
        ),
        LargeButton(
          icon: Icons.volunteer_activism_outlined,
          label: t.emergencyCanHelp,
          onPressed: available ? () => context.push(Routes.emergencyOffer) : null,
        ),
        LargeButton(
          icon: Icons.water_drop_outlined,
          label: t.emergencyResources,
          onPressed: available ? () => context.push(Routes.emergencyResources) : null,
        ),
        LargeButton(
          icon: Icons.local_phone_outlined,
          label: t.emergencyTitle,
          onPressed: () => context.push(Routes.emergency),
        ),
        LargeButton(
          icon: Icons.handyman_outlined,
          label: t.emergencyUsefulServices,
          onPressed: () {
            ref.read(imagesEnabledProvider.notifier).set(false);
            context.go('${Routes.directory}?emergencia=1');
          },
        ),
        if (scope != null) ...[
          LargeButton(
            icon: Icons.contact_phone_outlined,
            label: t.emergencyContacts,
            onPressed: () => context.push(Routes.emergencyContacts),
          ),
          for (final request in data?.requests ?? const <OwnHelpRequest>[])
            OutlinedButton.icon(
              icon: const Icon(Icons.assignment_outlined),
              label: Text('${t.emergencyMyRequest} · ${requestStatusLabel(t, request.status)}'),
              onPressed: () => context.push('/emergencia/pedidos/${request.id}'),
            ),
        ],
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(t.emergencyImages),
          subtitle: Text(t.emergencyImagesHelp),
          value: ref.watch(imagesEnabledProvider),
          onChanged: (value) => ref.read(imagesEnabledProvider.notifier).set(value),
        ),
        const EmergencyAlternatives(),
        OutlinedButton.icon(
          icon: const Icon(Icons.person_outline),
          label: Text(t.accountTitle),
          onPressed: () => context.go(Routes.account),
        ),
      ],
    );
  }
}

/// Practice only: simulate an emergency to show the whole flow without a server or allies.
class _SimulationPanel extends StatelessWidget {
  const _SimulationPanel({required this.practice, required this.eventActive});
  final PracticeEmergencyRepository practice;
  final bool eventActive;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.simulationTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(t.simulationHelp, style: TextStyle(color: scheme.onTertiaryContainer)),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: Icon(eventActive ? Icons.stop_circle_outlined : Icons.warning_amber_rounded),
              label: Text(eventActive ? t.simulationEventOff : t.simulationEventOn),
              onPressed: () => practice.simulateEvent(active: !eventActive),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.water_drop_outlined),
              label: Text(t.simulationResource),
              onPressed: practice.simulateResource,
            ),
          ],
        ),
      ),
    );
  }
}
