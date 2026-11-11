import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/mode/app_mode.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/spaced.dart';
import 'package:vecinal/core/ui/wrapping_app_bar.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_directory_page.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_ui.dart';
import 'package:vecinal/features/emergencias/presentation/own_help_requests.dart';
import 'package:vecinal/features/emergencias/public_emergency_directory.dart';
import 'package:vecinal/features/mapa/presentation/map_view.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// "Números y lugares de emergencia" (section 5.6): it opens with the official numbers, one per
/// row with its call button, and then the verified places. It works without signal or session.
class EmergencyPage extends ConsumerWidget {
  const EmergencyPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final directory = ref.watch(publicEmergencyDirectoryProvider);
    final emergency = ref.watch(appModeProvider) != AppMode.normal;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Scaffold(
      appBar: wrappingAppBar(context, t.emergencyDirectoryTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: spaced([
            Semantics(
              header: true,
              child: Text(t.emergencyLifeRisk, style: theme.textTheme.titleMedium),
            ),
            Text(t.connectsNeighbors, style: muted),
            directory.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => EmergencyNotice(
                icon: Icons.error_outline,
                text: t.emergencyDirectoryUnavailable,
                tone: NoticeTone.danger,
              ),
              data: (data) {
                final now = ref.watch(clockProvider)();
                final numbers = data.entries.where((e) => e.number != null).toList();
                final places = data.entries.where((e) => e.number == null).toList();
                final online = ref.watch(syncStatusProvider).value?.connected == true;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            for (final (index, entry) in numbers.indexed) ...[
                              if (index > 0) const Divider(height: 1, indent: 18, endIndent: 18),
                              _NumberRow(entry: entry, stale: entry.staleAt(now)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            data.bundled ? Icons.inventory_2_outlined : Icons.offline_pin_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${data.bundled ? t.emergencyDirectoryBundled : t.emergencyDirectoryDownloaded}'
                            ' · ${t.updatedAgo(timeAgo(data.generatedAt, now, t)).toLowerCase()}',
                            style: muted,
                          ),
                        ),
                      ],
                    ),
                    if (!online)
                      EmergencyNotice(
                        icon: Icons.cloud_off_outlined,
                        text: t.emergencyOfflineWarning,
                      ),
                    const OwnHelpRequests(),
                    Semantics(
                      header: true,
                      child: Text(t.emergencyPlacesTitle, style: theme.textTheme.titleLarge),
                    ),
                    if (places.isEmpty)
                      EmergencyNotice(
                        icon: Icons.place_outlined,
                        text: t.emergencyNoLocations,
                        tone: NoticeTone.info,
                      ),
                    for (final entry in places) _PlaceCard(entry: entry, stale: entry.staleAt(now)),
                  ],
                );
              },
            ),
            if (emergency)
              OutlinedButton.icon(
                icon: const Icon(Icons.home_outlined),
                label: Text(t.emergencyExitLocalMode),
                onPressed: () {
                  final mode = ref.read(appModeProvider.notifier);
                  if (ref.read(appModeProvider) == AppMode.emergency) mode.endEvent();
                  mode.closeRecovery();
                  context.go(Routes.home);
                },
              ),
          ]),
        ),
      ),
    );
  }
}

/// One number per row: the number big, its name and source, and "Llamar" on the right.
class _NumberRow extends ConsumerWidget {
  const _NumberRow({required this.entry, required this.stale});
  final PublicEmergencyEntry entry;
  final bool stale;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = callColors(theme.colorScheme);
    final number = entry.number!;
    final call = FilledButton.icon(
      icon: const Icon(Icons.phone),
      label: Text(t.callAction),
      style: FilledButton.styleFrom(
        backgroundColor: colors.button,
        foregroundColor: colors.onButton,
      ),
      onPressed: () => _call(context, ref, number),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Semantics(
          label: t.emergencyPhoneLabel(number),
          excludeSemantics: true,
          child: Text(
            number,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Text(entry.label, style: theme.textTheme.titleMedium),
        _SourceLink(entry: entry),
        if (stale) Text(t.emergencyStale, style: TextStyle(color: theme.colorScheme.error)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
      child: emergencyLargeText(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [details, call],
            )
          : Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 12),
                call,
              ],
            ),
    );
  }

  Future<void> _call(BuildContext context, WidgetRef ref, String number) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(practiceModeProvider).value != false) {
      messenger.showSnackBar(SnackBar(content: Text(t.emergencyPracticeExternal)));
      return;
    }
    var opened = false;
    try {
      opened = await ref.read(phoneDialerProvider).dial(number);
    } catch (_) {
      /* Explain on this screen. */
    }
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(t.callFailed)));
  }
}

/// "Fuente: MTC · verificado el 7/11/2026" in one short line; the web address opens on tap.
class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.entry});
  final PublicEmergencyEntry entry;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = t.emergencySourceShort(entry.sourceName, formatEmergencyDate(entry.verifiedAt));
    final style = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final url = entry.sourceUrl;
    if (url == null) return Text(text, style: style);
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => launchUrl(url, mode: LaunchMode.externalApplication),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: style?.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A verified place (meeting point, health center or shelter) with its source and the map.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.entry, required this.stale});
  final PublicEmergencyEntry entry;
  final bool stale;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final icon = switch (entry.kind) {
      PublicEmergencyKind.meetingPoint => Icons.groups_outlined,
      PublicEmergencyKind.healthCenter => Icons.local_hospital_outlined,
      PublicEmergencyKind.shelter => Icons.night_shelter_outlined,
      PublicEmergencyKind.phone => Icons.phone_outlined,
    };
    final kind = switch (entry.kind) {
      PublicEmergencyKind.meetingPoint => t.emergencyTypeMeetingPoint,
      PublicEmergencyKind.healthCenter => t.emergencyTypeHealthCenter,
      PublicEmergencyKind.shelter => t.emergencyTypeShelter,
      PublicEmergencyKind.phone => t.emergencyTypeNumber,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmergencyIconBadge(icon: icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(kind, style: theme.textTheme.labelLarge),
                      Text(entry.label, style: theme.textTheme.titleMedium),
                      if (entry.address != null) Text(entry.address!),
                      if (entry.description != null) Text(entry.description!),
                      _SourceLink(entry: entry),
                      if (stale)
                        Text(t.emergencyStale, style: TextStyle(color: theme.colorScheme.error)),
                    ],
                  ),
                ),
              ],
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
                      detail: t.emergencySourceShort(
                        entry.sourceName,
                        formatEmergencyDate(entry.verifiedAt),
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
