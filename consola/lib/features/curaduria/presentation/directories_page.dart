import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal_consola/core/router/routes.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/features/curaduria/data/curation_repositories.dart';
import 'package:vecinal_consola/features/curaduria/domain/directory.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Published emergency directories, one per district, with the version the app downloads.
class DirectoriesPage extends ConsumerWidget {
  const DirectoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final directories = ref.watch(directoriesProvider);
    return ConsolePage(
      title: l10n.curationTitle,
      subtitle: l10n.curationSubtitle,
      actions: [
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(directoriesProvider),
          icon: const Icon(Icons.refresh),
          label: Text(l10n.refresh),
        ),
      ],
      child: AsyncBody(
        value: directories,
        onRetry: () => ref.invalidate(directoriesProvider),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            if (list.isEmpty)
              InfoCard(icon: Icons.folder_off_outlined, title: l10n.curationEmpty)
            else
              for (final directory in list) _DirectoryCard(directory: directory),
          ],
        ),
      ),
    );
  }
}

class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({required this.directory});

  final DirectorySummary directory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return FocusableCard(
      onTap: () => context.go(Routes.directory(directory.file)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(directory.file, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                icon: Icons.history_edu_outlined,
                label: l10n.curationVersion(directory.version),
              ),
              StatusBadge(
                icon: Icons.map_outlined,
                label: l10n.curationZones(directory.zones.length),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.curationHash(directory.sha256.substring(0, 12), directory.bytes),
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
