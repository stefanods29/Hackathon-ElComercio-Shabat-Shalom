import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_post_card.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Muro de publicaciones del prototipo.
class WallScreen extends StatefulWidget {
  const WallScreen({super.key});

  @override
  State<WallScreen> createState() => _WallScreenState();
}

class _WallScreenState extends State<WallScreen> {
  int pending = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final posts = mockPosts;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wallTitle),
        actions: [
          Badge(
            isLabelVisible: pending > 0,
            label: Text('$pending'),
            child: IconButton(
              key: const ValueKey<String>('wall-review'),
              tooltip: l10n.actionsToReview,
              icon: const Icon(Icons.inbox_outlined),
              onPressed: () => ProtoNavigation.open(context, ProtoRoutes.toReview),
            ),
          ),
          IconButton(
            key: const ValueKey<String>('wall-account'),
            tooltip: l10n.accountTitle,
            icon: const Icon(Icons.person_outline),
            onPressed: () => ProtoNavigation.open(context, ProtoRoutes.account),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (pending > 0)
              Material(
                color: kWarningColor.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_outlined, color: kWarningColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.pushPending,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: posts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forum_outlined, size: 48, color: kPrimaryColor),
                            const SizedBox(height: 16),
                            Text(
                              l10n.wallEmpty,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            ProtoButton(
                              text: l10n.publishAction,
                              icon: Icons.add,
                              onPressed: () => context.go(ProtoRoutes.publish),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      key: const PageStorageKey<String>('prototype-wall-screen'),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: posts.length,
                      itemBuilder: (context, index) => ProtoPostCard(
                        post: posts[index],
                        onTap: () =>
                            ProtoNavigation.open(context, '/publicaciones/${posts[index].id}'),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: ProtoButton(
        key: const ValueKey<String>('wall-publish'),
        text: l10n.publishAction,
        icon: Icons.add,
        onPressed: () => context.go(ProtoRoutes.publish),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
