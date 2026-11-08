import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/data/models.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';

/// Tarjeta de publicación para el muro del prototipo.
/// Usa la paleta de colores con jerarquía visual clara.
class ProtoPostCard extends StatelessWidget {
  final PostProto post;
  final VoidCallback? onTap;

  const ProtoPostCard({super.key, required this.post, this.onTap});

  Color _statusColor(String status) {
    switch (status) {
      case 'savedOnPhone':
        return kStatusSavedColor;
      case 'accepted':
        return kStatusAcceptedColor;
      case 'rejected':
        return kStatusRejectedColor;
      default:
        return kSecondaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(post.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      post.typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    post.ago,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                post.title,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: kTextColor),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Text(post.author, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                  const SizedBox(width: 16),
                  const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Text(post.zone, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      post.status == 'accepted'
                          ? Icons.check_circle
                          : post.status == 'rejected'
                              ? Icons.error
                              : Icons.schedule,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      post.statusLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
