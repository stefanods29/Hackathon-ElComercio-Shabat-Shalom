import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/features/emergencias/public_emergency_directory.dart';
import 'package:vecinal/features/mapa/presentation/map_view.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class EmergencyPage extends ConsumerWidget {
  const EmergencyPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final directory = ref.watch(publicEmergencyDirectoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.emergencyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.connectsNeighbors, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(t.emergencyLifeRisk, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            directory.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text(t.actionFailed),
              data: (data) {
                final entries = data.entries;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(data.bundled ? t.emergencyBackup : t.emergencyUpdated),
                    for (final entry in entries)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                    var opened = false;
                                    try {
                                      opened = await ref
                                          .read(phoneDialerProvider)
                                          .dial(entry.number!);
                                    } catch (_) {
                                      /* Explain on this screen. */
                                    }
                                    if (!opened && context.mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(SnackBar(content: Text(t.callFailed)));
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
          ],
        ),
      ),
    );
  }
}
