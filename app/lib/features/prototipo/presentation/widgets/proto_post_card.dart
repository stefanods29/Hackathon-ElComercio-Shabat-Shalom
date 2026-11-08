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
    button: onTap != null,
    child: Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                    style: const TextStyle(
                      fontSize: 14,
                      color: kPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(post.ago, style: const TextStyle(fontSize: 14, color: kTextSecondaryColor)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: kTextColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${post.author} · ${post.zone}',
                style: const TextStyle(fontSize: 14, color: kTextSecondaryColor),
              ),
              const SizedBox(height: 16),
              ProtoStatusBadge(post: post),
            ],
          ),
        ),
      ),
    ),
  );
}
