import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/connection_banner.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(texts.wallTitle),
        actions: [
          IconButton(
            tooltip: texts.mapTitle,
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push(Routes.map),
          ),
          IconButton(
            tooltip: texts.actionsToReview,
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => context.push(Routes.toReview),
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
