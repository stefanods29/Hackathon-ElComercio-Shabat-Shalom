import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/mode/app_mode.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/core/ui/spaced.dart';
import 'package:vecinal/core/ui/wrapping_app_bar.dart';
import 'package:vecinal/features/emergencias/data/providers.dart';
import 'package:vecinal/features/emergencias/presentation/own_help_requests.dart';
import 'package:vecinal/features/emergencias/public_emergency_directory.dart';
import 'package:vecinal/features/mapa/presentation/map_view.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class EmergencyPage extends ConsumerWidget {
  const EmergencyPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final directory = ref.watch(publicEmergencyDirectoryProvider);
    final emergency = ref.watch(appModeProvider) == AppMode.emergency;
    final boardAvailable =
        ref.watch(emergencyBoardRepositoryProvider) != null &&
        ref.watch(practiceModeProvider).asData?.value == false;
    return Scaffold(
      appBar: wrappingAppBar(context, t.emergencyTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: spaced([
            Text(t.connectsNeighbors, style: Theme.of(context).textTheme.titleLarge),
            LargeButton(
              icon: Icons.emergency_outlined,
              label: t.activateLocalEmergency,
              onPressed: () {
                ref.read(appModeProvider.notifier).activateEmergency();
                context.go(Routes.emergencyDashboard);
              },
            ),
            const SizedBox(height: 12),
            Text(t.emergencyLifeRisk, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                final mode = ref.read(appModeProvider.notifier);
                if (emergency) {
                  mode.endEvent();
                  mode.closeRecovery();
                } else {
                  mode.activateEmergency();
                }
              },
              child: Text(emergency ? t.emergencyBoardExitMode : t.emergencyBoardActivateMode),
            ),
            if (emergency) Text(t.emergencyBoardImagesPaused),
            if (boardAvailable)
              OutlinedButton(
                onPressed: () => context.push(Routes.emergencyBoardData),
                child: Text(t.emergencyBoardTitle),
              ),
            const OwnHelpRequests(),
            directory.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text(t.actionFailed),
              data: (data) {
                final entries = data.entries;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Text(data.bundled ? t.emergencyBackup : t.emergencyUpdated),
                    Text(t.updatedAgo(timeAgo(data.generatedAt, ref.watch(clockProvider)(), t))),
                    if (ref.watch(syncStatusProvider).value?.connected != true)
                      Text(t.emergencyOfflineWarning),
                    for (final entry in entries)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 12,
                            children: [
                              Text(entry.label, style: Theme.of(context).textTheme.titleLarge),
                              if (entry.description != null) Text(entry.description!),
                              if (entry.address != null) Text(entry.address!),
                              if (entry.number != null)
                                Text(
                                  entry.number!,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                              Text(
                                t.sourceAndDate(
                                  entry.sourceCitation,
                                  DateFormat.yMd(t.localeName).format(entry.verifiedAt),
                                ),
                              ),
                              if (entry.staleAt(ref.watch(clockProvider)())) Text(t.emergencyStale),
                              if (entry.number != null)
                                FilledButton.icon(
                                  icon: const Icon(Icons.phone_outlined),
                                  label: Text(t.callAction),
                                  onPressed: () async {
                                    if (ref.read(practiceModeProvider).value != false) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(t.emergencyPracticeExternal)),
                                      );
                                      return;
                                    }
                                    var opened = false;
                                    try {
                                      opened = await ref
                                          .read(phoneDialerProvider)
                                          .dial(entry.number!);
                                    } catch (_) {
                                      /* Explain on this screen. */
                                    }
                                    if (!opened && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(SnackBar(content: Text(t.callFailed)));
                                    }
                                  },
                                ),
                              if (entry.location != null)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.map_outlined),
                                  label: Text(t.openOnMap),
                                  onPressed: () => context.push(
                                    Routes.emergencyMap,
                                    extra: MapFocus([
                                      MapMarker(
                                        label: entry.label,
                                        location: entry.location!,
                                        detail: t.sourceAndDate(
                                          entry.sourceCitation,
                                          DateFormat.yMd(t.localeName).format(entry.verifiedAt),
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (!entries.any((e) => e.location != null)) Text(t.emergencyNoLocations),
                  ],
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}
