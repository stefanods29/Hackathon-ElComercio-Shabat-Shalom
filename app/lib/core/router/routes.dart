/// App routes. Each lot adds its own here and its screen in `router.dart`.
/// Paths are deep links the neighbor may see, so they stay in Spanish.
abstract final class Routes {
  static const home = '/';
  static const publish = '/publicar';
  static const toReview = '/por-revisar';
  static const emergency = '/emergencia';
  static const map = '/mapa';
  static const pushSettings = '/avisos';
  static const postDetail = '/publicaciones/:id';
  static const photos = '/fotos';
}
