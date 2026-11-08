import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_status_badge.dart';

/// Pantalla de detalle de una publicación.
class PostDetailScreen extends StatelessWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final post = mockPosts.firstWhere((p) => p.id == postId, orElse: () => mockPosts.first);
    final statusColor = protoStatusColor(post.status);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        title: const Text(
          'Detalle',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: const ProtoBackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    post.typeLabel,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_outline, size: 20, color: kTextSecondaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.author,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: kTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            post.zone,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: kTextSecondaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.ago,
                        style: const TextStyle(fontSize: 14, color: kTextSecondaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ProtoStatusBadge(post: post),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kSurfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Descripción',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.title.length > 50
                            ? 'Descripción detallada de "${post.title}" — más información sobre esta publicación estaría aquí en una versión completa de la app.'
                            : 'Descripción de "${post.title}" — más información sobre esta publicación estaría aquí en una versión completa de la app.',
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ProtoButton(
                  text: 'Volver al muro',
                  icon: Icons.arrow_back,
                  onPressed: () => context.go(ProtoRoutes.home(ProtoHomeTab.wall)),
                  fullWidth: true,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
