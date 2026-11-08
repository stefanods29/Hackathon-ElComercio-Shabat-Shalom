import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/sync/sync_service.dart';
import 'package:vecinal/core/theme/vecinal_tokens.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/connection_banner.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/core/ui/simple_mode.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/presentation/widgets/post_card.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Muro local del barrio. Las publicaciones siguen visibles sin conexión y
/// cada una conserva su estado real de envío.
class WallPage extends ConsumerWidget {
  const WallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final wall = ref.watch(wallProvider);
    final signOut = ref.watch(demoSignOutProvider);
    final syncStatus = ref.watch(syncStatusProvider).value ?? SyncStatus.initial;
    final simpleMode = ref.watch(simpleModeProvider).value == true;
    final tokens = context.vecinalTokens;

    return Scaffold(
      appBar: AppBar(
        title: Text(texts.wallTitle),
        actions: [
          if (!simpleMode)
            IconButton(
              key: const ValueKey<String>('open-map'),
              tooltip: texts.mapTitle,
              icon: const Icon(Icons.map_outlined),
              onPressed: () => context.push(Routes.map),
            ),
          if (!simpleMode)
            Badge.count(
              count: syncStatus.pendingUploads,
              isLabelVisible: syncStatus.pendingUploads > 0,
              child: IconButton(
                key: const ValueKey<String>('open-actions-to-review'),
                tooltip: texts.actionsToReview,
                icon: const Icon(Icons.inbox_outlined),
                onPressed: () => context.push(Routes.toReview),
              ),
            ),
          MenuAnchor(
            menuChildren: [
              MenuItemButton(
                key: const ValueKey<String>('toggle-simple-mode'),
                leadingIcon: Icon(
                  simpleMode ? Icons.check_circle_outline : Icons.accessibility_new,
                ),
                onPressed: () => ref.read(simpleModeProvider.notifier).toggle(),
                child: Text(
                  simpleMode ? texts.simpleModeEnabledLabel : texts.simpleModeDisabledLabel,
                ),
              ),
              if (!simpleMode) ...[
                MenuItemButton(
                  key: const ValueKey<String>('open-notification-settings'),
                  leadingIcon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push(Routes.pushSettings),
                  child: Text(texts.pushTitle),
                ),
                MenuItemButton(
                  key: const ValueKey<String>('open-tutorial'),
                  leadingIcon: const Icon(Icons.lightbulb_outline),
                  onPressed: () => context.push(Routes.tutorial),
                  child: Text(texts.viewTutorial),
                ),
              ],
              MenuItemButton(
                key: const ValueKey<String>('open-account'),
                leadingIcon: const Icon(Icons.person_outline),
                onPressed: () => context.push(Routes.account),
                child: Text(texts.accountTitle),
              ),
              if (signOut != null)
                MenuItemButton(
                  key: const ValueKey<String>('demo-sign-out'),
                  leadingIcon: const Icon(Icons.logout),
                  onPressed: () => _confirmDemoSignOut(context, texts, signOut),
                  child: Text(texts.demoSignOut),
                ),
            ],
            builder: (context, controller, child) => IconButton(
              key: const ValueKey<String>('more-options'),
              tooltip: texts.moreOptions,
              icon: const Icon(Icons.more_horiz),
              onPressed: controller.isOpen ? controller.close : controller.open,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnectionBanner(),
          if (syncStatus.lastSyncedAt case final lastSyncedAt?)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  tokens.spaceLg,
                  tokens.spaceSm,
                  tokens.spaceLg,
                  tokens.spaceXs,
                ),
                child: Text(
                  texts.updatedAgo(timeAgo(lastSyncedAt, ref.watch(clockProvider)(), texts)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: wall.when(
                  data: (posts) => _WallFeed(
                    posts: posts,
                    onRefresh: () async {
                      ref.invalidate(wallProvider);
                      try {
                        await ref.read(wallProvider.future);
                      } on Object {
                        // The feed's error state keeps the retry action visible.
                      }
                    },
                    emptyMessage: texts.wallEmpty,
                    publishLabel: texts.publishAction,
                    onPublish: () => context.push(Routes.publish),
                  ),
                  loading: () => _WallLoading(label: texts.wallLoading),
                  error: (error, stackTrace) => _WallError(
                    message: texts.wallLoadError,
                    retryLabel: texts.retryAction,
                    onRetry: () => ref.invalidate(wallProvider),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('publish-post'),
        onPressed: () => context.push(Routes.publish),
        icon: const Icon(Icons.add),
        label: Text(texts.publishAction),
      ),
    );
  }

  Future<void> _confirmDemoSignOut(
    BuildContext context,
    AppLocalizations texts,
    VoidCallback signOut,
  ) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: Text(texts.demoSignOut),
        content: Text(texts.demoSignOutWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(texts.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(texts.demoSignOut),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) signOut();
  }
}

class _WallFeed extends StatelessWidget {
  const _WallFeed({
    required this.posts,
    required this.onRefresh,
    required this.emptyMessage,
    required this.publishLabel,
    required this.onPublish,
  });

  final List<Post> posts;
  final Future<void> Function() onRefresh;
  final String emptyMessage;
  final String publishLabel;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final tokens = context.vecinalTokens;
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: posts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(tokens.spaceXl),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.42,
                  child: _WallEmpty(
                    message: emptyMessage,
                    publishLabel: publishLabel,
                    onPublish: onPublish,
                  ),
                ),
              ],
            )
          : ListView.separated(
              key: const ValueKey<String>('wall-post-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsetsDirectional.fromSTEB(
                tokens.spaceLg,
                tokens.spaceMd,
                tokens.spaceLg,
                tokens.space2xl,
              ),
              itemCount: posts.length,
              separatorBuilder: (context, index) => SizedBox(height: tokens.spaceMd),
              itemBuilder: (context, index) => PostCard(post: posts[index]),
            ),
    );
  }
}

class _WallEmpty extends StatelessWidget {
  const _WallEmpty({required this.message, required this.publishLabel, required this.onPublish});

  final String message;
  final String publishLabel;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.vecinalTokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volunteer_activism_outlined, size: 48, color: scheme.primary),
            SizedBox(height: tokens.spaceLg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.spaceLg),
            LargeButton(
              icon: Icons.add,
              label: publishLabel,
              fullWidth: true,
              onPressed: onPublish,
            ),
          ],
        ),
      ),
    );
  }
}

class _WallLoading extends StatelessWidget {
  const _WallLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.vecinalTokens;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: ListView.separated(
          padding: EdgeInsets.all(tokens.spaceLg),
          itemCount: 3,
          separatorBuilder: (context, index) => SizedBox(height: tokens.spaceMd),
          itemBuilder: (context, index) => Card.outlined(
            child: Padding(
              padding: EdgeInsets.all(tokens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.42,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                      ),
                      child: SizedBox(height: tokens.spaceMd),
                    ),
                  ),
                  SizedBox(height: tokens.spaceMd),
                  FractionallySizedBox(
                    widthFactor: 0.8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                      ),
                      child: SizedBox(height: tokens.spaceLg),
                    ),
                  ),
                  SizedBox(height: tokens.spaceLg),
                  FractionallySizedBox(
                    widthFactor: 0.32,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(tokens.radiusLg),
                      ),
                      child: SizedBox(height: tokens.space2xl),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WallError extends StatelessWidget {
  const _WallError({required this.message, required this.retryLabel, required this.onRetry});

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.vecinalTokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: Theme.of(context).colorScheme.error, size: 40),
            SizedBox(height: tokens.spaceMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: tokens.spaceLg),
            FilledButton.icon(
              key: const ValueKey<String>('retry-wall'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
