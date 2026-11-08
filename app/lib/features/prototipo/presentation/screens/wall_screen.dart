import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_post_card.dart';
import 'package:vecinal/l10n/app_localizations.dart';

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
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        title: const Text(
          'Muro',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).actionsToReview,
            icon: const Icon(Icons.notifications_outlined, color: kTextColor),
            onPressed: () => ProtoNavigation.open(context, ProtoRoutes.toReview),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: AppLocalizations.of(context).accountTitle,
            icon: const Icon(Icons.person_outline),
            onPressed: () => ProtoNavigation.open(context, ProtoRoutes.account),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (pending > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: kWarningColor.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: kWarningColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$pending publicación${pending > 1 ? 'es' : ''} guardada${pending > 1 ? 's' : ''} en tu celular',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kWarningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.note_add, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Aún no hay publicaciones en tu zona.',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        return ProtoPostCard(
                          post: posts[index],
                          onTap: () =>
                              ProtoNavigation.open(context, '/publicaciones/${posts[index].id}'),
                        );
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
