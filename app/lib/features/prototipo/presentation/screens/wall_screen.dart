import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_post_card.dart';

/// Pantalla del muro (home). Muestra publicaciones y permite publicar.
class WallScreen extends StatefulWidget {
  const WallScreen({super.key});

  @override
  State<WallScreen> createState() => _WallScreenState();
}

class _WallScreenState extends State<WallScreen> {
  int pending = 1;

  @override
  Widget build(BuildContext context) {
    final posts = mockPosts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Muro'),
        actions: [
          ProtoButton(
            text: 'Cuenta',
            icon: Icons.person_outline,
            onPressed: () => context.go('/cuenta'),
            secondary: true,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Contador de pendientes
            if (pending > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: const Color(0xFFFFAB00).withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Color(0xFFFFAB00)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$pending publicación${pending > 1 ? 'es' : ''} guardada${pending > 1 ? 's' : ''} en tu celular',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFFFAB00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: posts.isEmpty
                  ? const Center(child: Text('Aún no hay publicaciones en tu zona.'))
                  : ListView.builder(
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        return ProtoPostCard(post: posts[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: ProtoButton(
        text: 'Publicar',
        icon: Icons.add,
        onPressed: () => context.go('/publicar'),
        fullWidth: false,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
