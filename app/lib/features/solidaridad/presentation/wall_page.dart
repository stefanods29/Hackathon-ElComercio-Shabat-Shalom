import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/mode/app_mode.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/sync/sync_service.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/connection_banner.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_dashboard_page.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/features/solidaridad/presentation/widgets/post_card.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Favor wall of the zone. Phase 0 reference screen: it reads from the local database
/// (here, the in-memory double) and shows the submission status of every change.
class WallPage extends ConsumerWidget {
  const WallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(emergencyHomeProvider)) return const EmergencyDashboardPage();
    final texts = AppLocalizations.of(context);
    final wall = ref.watch(wallProvider);
    final signOut = ref.watch(demoSignOutProvider);
    final syncStatus = ref.watch(syncStatusProvider).value ?? SyncStatus.initial;
    final lastSyncedAt = syncStatus.lastSyncedAt;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(texts.wallTitle),
        actions: [
          IconButton(
            tooltip: texts.mapTitle,
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push(Routes.map),
          ),
          Stack(
            children: [
              IconButton(
                tooltip: texts.actionsToReview,
                icon: const Icon(Icons.inbox_outlined),
                onPressed: () => context.push(Routes.toReview),
              ),
              if (syncStatus.pendingUploads > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      '${syncStatus.pendingUploads}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          if (signOut != null)
            IconButton(
              tooltip: texts.demoSignOut,
              icon: const Icon(Icons.logout),
              onPressed: () async {
                if (ref.read(practiceModeProvider).value != false) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(texts.practiceHelp)));
                  return;
                }
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: Text(texts.demoSignOut),
                    content: Text(texts.demoSignOutWarning),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: Text(texts.cancelAction),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: Text(texts.demoSignOut),
                      ),
                    ],
                  ),
                );
                if (confirmed == true &&
                    context.mounted &&
                    ref.read(practiceModeProvider).value == false) {
                  signOut();
                }
              },
            ),
          PopupMenuButton<String>(
            tooltip: texts.moreOptions,
            icon: const Icon(Icons.more_vert),
            onSelected: (route) => context.push(route),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: Routes.photos,
                child: ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(texts.photosTitle),
                ),
              ),
              PopupMenuItem(
                value: Routes.pushSettings,
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(texts.pushTitle),
                ),
              ),
              PopupMenuItem(
                value: Routes.tutorial,
                child: ListTile(
                  leading: const Icon(Icons.tips_and_updates_outlined),
                  title: Text(texts.viewTutorial),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: wall.when(
              data: (posts) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
                children: [
                  Text(
                    texts.wallSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () => ref.read(appModeProvider.notifier).activateEmergency(),
                            child: _QuickAction(
                              icon: Icons.emergency_outlined,
                              label: texts.activateLocalEmergency,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              foregroundColor: theme.colorScheme.onPrimaryContainer,
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () => context.go(Routes.directory),
                            child: _QuickAction(
                              icon: Icons.handyman_outlined,
                              label: texts.directoryTitle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(texts.wallLatest, style: theme.textTheme.titleLarge),
                  if (lastSyncedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      texts.updatedAgo(timeAgo(lastSyncedAt, ref.watch(clockProvider)(), texts)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (posts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Text(texts.wallEmpty, textAlign: TextAlign.center),
                    ),
                  for (final post in posts) PostCard(post: post),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(child: Text('$error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.publish),
        icon: const Icon(Icons.add),
        label: Text(texts.publishAction),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 28),
      const SizedBox(height: 12),
      Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2)),
    ],
  );
}
