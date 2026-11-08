import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/data/models.dart';

/// Tarjeta de publicación para el muro del prototipo.
/// Muestra tipo, título, estado, autor, zona y tiempo.
class ProtoPostCard extends StatelessWidget {
  final PostProto post;
  final VoidCallback? onTap;

  const ProtoPostCard({super.key, required this.post, this.onTap});

  Color _statusColor(String status) {
    switch (status) {
      case 'savedOnPhone':
        return const Color(0xFFFFAB00); // ámbar
      case 'accepted':
        return const Color(0xFF2E7D32); // verde
      case 'rejected':
        return const Color(0xFFC62828); // rojo
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(post.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post.typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(post.status),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(post.ago, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),
              Text(post.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(post.author, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(width: 12),
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(post.zone, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(post.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _statusColor(post.status).withValues(alpha: 0.3)),
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
                      color: _statusColor(post.status),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      post.statusLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _statusColor(post.status),
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
