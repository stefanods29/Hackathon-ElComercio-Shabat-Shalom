import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla de detalle de una publicación.
class PostDetailScreen extends StatelessWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final post = mockPosts.firstWhere((p) => p.id == postId,
        orElse: () => mockPosts.first);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 16),
              Text(
                post.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 8),
              Text(post.ago, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  post.title.length > 50
                      ? 'Descripción detallada de "${post.title}" — más información sobre esta publicación estaría aquí en una versión completa de la app.'
                      : 'Descripción de "${post.title}" — más información sobre esta publicación estaría aquí en una versión completa de la app.',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const Spacer(),
              ProtoButton(
                text: 'Volver al muro',
                icon: Icons.arrow_back,
                onPressed: () => Navigator.pop(context),
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'savedOnPhone':
        return const Color(0xFFFFAB00);
      case 'accepted':
        return const Color(0xFF2E7D32);
      case 'rejected':
        return const Color(0xFFC62828);
      default:
        return Colors.grey;
    }
  }
}
