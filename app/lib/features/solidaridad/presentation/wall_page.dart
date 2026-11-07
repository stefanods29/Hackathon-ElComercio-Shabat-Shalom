import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/connection_banner.dart';
import 'package:vecinal/core/ui/submission_status_chip.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(texts.wallTitle),
        actions: [
          IconButton(
            tooltip: texts.actionsToReview,
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => context.push(Routes.toReview),
          ),
          if (signOut != null)
            IconButton(
              tooltip: texts.demoSignOut,
              icon: const Icon(Icons.logout),
              onPressed: () async {
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
                if (confirmed == true && context.mounted) signOut();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
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

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final canTake = post.isAvailable && post.authorId != session.neighborId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${post.type.apiValue.toUpperCase()} · ${post.category}',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(post.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SubmissionStatusChip(status: post.submissionStatus),
                if (canTake)
                  FilledButton(
                    onPressed: () => _take(context, ref),
                    child: Text(texts.takeFavorAction),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _take(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final useCase = TakeFavor(
      ref.read(postRepositoryProvider),
      currentNeighborId: ref.read(sessionProvider).neighborId,
    );
    try {
      await useCase.execute(post);
    } on LocalValidationError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
