import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/under_construction_screen.dart';
import 'package:vecinal/features/solidaridad/presentation/wall_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(path: Routes.home, builder: (context, state) => const WallPage()),
      GoRoute(
        path: Routes.publish,
        builder: (context, state) =>
            const UnderConstructionScreen(title: 'Publicar en 3 toques', lot: 'Lote D'),
      ),
      GoRoute(
        path: Routes.toReview,
        builder: (context, state) =>
            const UnderConstructionScreen(title: 'Acciones por revisar', lot: 'Lote D'),
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
