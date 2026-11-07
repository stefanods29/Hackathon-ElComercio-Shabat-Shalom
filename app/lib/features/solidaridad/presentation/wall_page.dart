import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/sync/sync_service.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/connection_banner.dart';
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
    final syncStatus = ref.watch(syncStatusProvider).value ?? SyncStatus.initial;
    final lastSyncedAt = syncStatus.lastSyncedAt;

    return Scaffold(
      appBar: AppBar(
        title: Text(texts.wallTitle),
        actions: [
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
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
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
          const TutorialButton(),
        ],
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          if (lastSyncedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    texts.updatedAgo(
                      timeAgo(lastSyncedAt, ref.watch(clockProvider)(), texts),
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
