import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/data/models.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';

Color protoStatusColor(String status) => switch (status) {
  'savedOnPhone' => kStatusSavedColor,
  'accepted' => kStatusAcceptedColor,
  'rejected' => kStatusRejectedColor,
  _ => kSecondaryColor,
};

/// Status always has an icon and text; color is only a complementary cue.
class ProtoStatusBadge extends StatelessWidget {
  const ProtoStatusBadge({super.key, required this.post});

  final PostProto post;

  @override
  Widget build(BuildContext context) {
    final color = protoStatusColor(post.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (post.status) {
              'accepted' => Icons.check_circle_outline,
              'rejected' => Icons.error_outline,
              _ => Icons.schedule,
            },
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              post.statusLabel,
              style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
