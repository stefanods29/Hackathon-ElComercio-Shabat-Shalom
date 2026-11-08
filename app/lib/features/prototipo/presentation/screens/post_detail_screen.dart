import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_status_badge.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Pantalla de detalle de una publicación.
class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final post = mockPosts.where((item) => item.id == postId).firstOrNull;
    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.postDetailTitle), leading: const ProtoBackButton()),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox_outlined, size: 48, color: kTextSecondaryColor),
                const SizedBox(height: 12),
                Text(l10n.postDetailUnavailable, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go(ProtoRoutes.home(ProtoHomeTab.wall)),
                  child: Text(l10n.postDetailBack),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final statusColor = protoStatusColor(post.status);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.postDetailTitle), leading: const ProtoBackButton()),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(kRadiusPill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      post.typeLabel,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(post.title, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    minTileHeight: 72,
                    leading: const CircleAvatar(
                      backgroundColor: kAvatarColor,
                      child: Icon(Icons.person_outline, color: kPrimaryColor),
                    ),
                    title: Text(post.author),
                    subtitle: Text('${post.zone} · ${post.ago}'),
                  ),
                ),
                const SizedBox(height: 16),
                ProtoStatusBadge(post: post),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.descriptionLabel, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          l10n.protoPostDescription(post.title),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ProtoButton(
                  key: const ValueKey<String>('post-detail-return'),
                  text: l10n.postDetailBack,
                  icon: Icons.arrow_back,
                  onPressed: () => context.go(ProtoRoutes.home(ProtoHomeTab.wall)),
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
