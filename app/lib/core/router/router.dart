import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/under_construction_screen.dart';
import 'package:vecinal/features/publicar/presentation/choose_type_page.dart';
import 'package:vecinal/features/publicar/presentation/publish_form_page.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/presentation/actions_to_review_page.dart';
import 'package:vecinal/features/solidaridad/presentation/wall_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(path: Routes.home, builder: (context, state) => const WallPage()),
      GoRoute(
        path: Routes.publish,
        builder: (context, state) => const ChooseTypePage(),
      ),
      GoRoute(
        path: Routes.publishForm,
        builder: (context, state) {
          final tipo = state.pathParameters['tipo']!;
          final postType = PostType.fromApi(tipo);
          return PublishFormPage(type: postType);
        },
      ),
      GoRoute(
        path: Routes.toReview,
        builder: (context, state) => const ActionsToReviewPage(),
      ),
      GoRoute(
        path: Routes.map,
        builder: (context, state) =>
            const UnderConstructionScreen(title: 'Mapa sin conexión', lot: 'Lote C'),
      ),
      GoRoute(
        path: Routes.emergency,
        builder: (context, state) =>
            const UnderConstructionScreen(title: 'Modo emergencia', lot: 'equipo en la Fase 1'),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
