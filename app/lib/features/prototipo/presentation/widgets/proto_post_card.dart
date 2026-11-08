import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/data/models.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_status_badge.dart';

class ProtoPostCard extends StatelessWidget {
  const ProtoPostCard({super.key, required this.post, this.onTap});

  final PostProto post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${post.typeLabel}. ${post.title}. ${post.statusLabel}. ${post.author}. ${post.zone}',
    button: onTap != null,
    child: Card(
      key: ValueKey<String>('post-card-${post.id}'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusCard),
        child: Padding(
          padding: const EdgeInsets.all(kSpacingGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    post.typeLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: kPrimaryColor),
                  ),
                  Text(post.ago, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(post.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('${post.author} · ${post.zone}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              ProtoStatusBadge(post: post),
            ],
          ),
        ),
      ),
    ),
  );
}
