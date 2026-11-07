import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/features/solidaridad/presentation/widgets/post_card.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Reads only the local wall; synchronization can populate an initially missing publication.
class PostDetailPage extends ConsumerWidget {
  const PostDetailPage({super.key, required this.postId});
  final String postId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(texts.postDetailTitle)),
      body: SafeArea(
        child: ref
            .watch(wallProvider)
            .when(
              data: (posts) {
                final matches = posts.where((post) => post.id == postId);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (matches.isNotEmpty)
                      PostCard(post: matches.first)
                    else
                      Text(texts.postDetailUnavailable),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go(Routes.home),
                      child: Text(texts.postDetailBack),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(texts.postDetailUnavailable)),
            ),
      ),
    );
  }
}
