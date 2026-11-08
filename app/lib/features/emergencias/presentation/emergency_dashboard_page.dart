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
        Text(t.connectsNeighbors),
        if (scope?.practice == true) Text(t.emergencyPracticeHelp),
        if (!ref.watch(emergencyHomeProvider))
          LargeButton(
            icon: Icons.emergency_outlined,
            label: t.activateLocalEmergency,
            onPressed: () => ref.read(appModeProvider.notifier).activateEmergency(),
          ),
        Text(t.emergencyLocalModeHelp),
        if (data?.activeEvent != true && ref.watch(appModeProvider) == AppMode.emergency)
          OutlinedButton.icon(
            icon: const Icon(Icons.home_outlined),
            label: Text(t.emergencyExitLocalMode),
            onPressed: () {
              final mode = ref.read(appModeProvider.notifier);
              mode.endEvent();
              mode.closeRecovery();
            },
          ),
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
            context.push('${Routes.directory}?emergencia=1');
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
          onPressed: () => context.push(Routes.account),
        ),
      ],
    );
  }
}
