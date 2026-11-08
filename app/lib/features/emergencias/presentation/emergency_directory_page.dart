import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/ui/notice_card.dart';
import 'package:vecinal/core/ui/spaced.dart';
import 'package:vecinal/features/emergencias/data/providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency_directory.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// `dd/mm/aaaa` of the date as it is, without moving it to another time zone.
String formatEmergencyDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Basic emergency directory (Lot A, part 2). It opens without signal and without a session, and
/// shows the source and the verification date of every entry. Lot D adds "Estoy en emergencia",
/// the calls and the map.
class EmergencyDirectoryPage extends ConsumerWidget {
  const EmergencyDirectoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final directory = ref.watch(emergencyDirectoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(texts.emergencyDirectoryTitle)),
      body: SafeArea(
        child: directory.when(
          data: (value) => _DirectoryList(directory: value),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(texts.emergencyDirectoryUnavailable, textAlign: TextAlign.center),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _DirectoryList extends ConsumerWidget {
  const _DirectoryList({required this.directory});

  final EmergencyDirectory directory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final policy = ref.watch(emergencyStalenessPolicyProvider);
    final now = ref.watch(clockProvider)();
    final isBackup = directory.origin == EmergencyDirectoryOrigin.backup;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: spaced([
        Text(texts.emergencyLifeRisk, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        NoticeCard(
          icon: isBackup ? Icons.inventory_2_outlined : Icons.offline_pin_outlined,
          title: isBackup ? texts.emergencyDirectoryBackupTitle : directory.district,
          detail: isBackup
              ? texts.emergencyDirectoryBackup
              : texts.emergencyDirectorySaved(formatEmergencyDate(directory.generatedAt.toLocal())),
        ),
        const SizedBox(height: 16),
        for (final entry in directory.entries) ...[
          _EntryCard(entry: entry, outdated: policy.isPossiblyOutdated(entry, now)),
          const SizedBox(height: 12),
        ],
        Text(texts.connectsNeighbors),
      ]),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.outdated});

  final EmergencyEntry entry;
  final bool outdated;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final phone = entry.phone;
    final address = entry.address;
    final description = entry.description;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(_typeLabel(texts, entry.type), style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(entry.name, style: theme.textTheme.titleLarge),
            if (phone != null) ...[
              const SizedBox(height: 8),
              Semantics(
                label: texts.emergencyPhoneLabel(phone),
                excludeSemantics: true,
                child: Text(
                  phone,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            if (address != null) ...[const SizedBox(height: 8), Text(address)],
            if (description != null) ...[const SizedBox(height: 8), Text(description)],
            const SizedBox(height: 8),
            Text(
              texts.emergencySourceAndDate(
                entry.source.name,
                formatEmergencyDate(entry.verifiedOn),
              ),
            ),
            if (outdated) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_outlined, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(texts.emergencyPossiblyOutdated)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _typeLabel(AppLocalizations texts, EmergencyEntryType type) => switch (type) {
    EmergencyEntryType.number => texts.emergencyTypeNumber,
    EmergencyEntryType.meetingPoint => texts.emergencyTypeMeetingPoint,
    EmergencyEntryType.healthCenter => texts.emergencyTypeHealthCenter,
    EmergencyEntryType.shelter => texts.emergencyTypeShelter,
  };
}
