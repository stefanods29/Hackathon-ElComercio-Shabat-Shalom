import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/sync/sync_service.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/connection_banner.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/features/onboarding/tutorial_screen.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/features/solidaridad/presentation/widgets/post_card.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Favor wall of the zone. Phase 0 reference screen: it reads from the local database
/// (here, the in-memory double) and shows the submission status of every change.
class WallPage extends ConsumerWidget {
  const WallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final wall = ref.watch(wallProvider);
    final signOut = ref.watch(demoSignOutProvider);
    final syncStatus = ref.watch(syncStatusProvider).value ?? SyncStatus.initial;
    final lastSyncedAt = syncStatus.lastSyncedAt;

    return Scaffold(
      appBar: AppBar(
        title: Text(texts.wallTitle),
        actions: [
          IconButton(
            tooltip: texts.photosTitle,
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => context.push(Routes.photos),
          ),
          IconButton(
            tooltip: texts.pushTitle,
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(Routes.pushSettings),
          ),
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
          IconButton(
            tooltip: texts.accountTitle,
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(Routes.account),
          ),
          const TutorialButton(),
        ],
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => context.push(Routes.emergency),
                  icon: const Icon(Icons.emergency_outlined),
                  label: Text(texts.emergencyTitle),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push(Routes.directory),
                  icon: const Icon(Icons.handyman_outlined),
                  label: Text(texts.directoryTitle),
                ),
              ],
            ),
          ),
          if (lastSyncedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      texts.updatedAgo(timeAgo(lastSyncedAt, ref.watch(clockProvider)(), texts)),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: wall.when(
              data: (posts) => posts.isEmpty
                  ? Center(child: Text(texts.wallEmpty))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: posts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => PostCard(post: posts[index]),
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
