/// App routes. Each lot adds its own here and its screen in `router.dart`.
/// Paths are deep links the neighbor may see, so they stay in Spanish.
abstract final class Routes {
  static const home = '/';
  static const publish = '/publicar';
  static const publishForm = '/publicar/:tipo';
  static const toReview = '/por-revisar';
  static const emergency = '/emergencia';
  static const map = '/mapa';
  static const tutorial = '/tutorial';
  static const signIn = '/ingresar';
  static const signInCode = '/ingresar/codigo';
  static const chooseZone = '/elegir-zona';
  static const account = '/cuenta';
}
