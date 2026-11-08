/// App routes. Each lot adds its own here and its screen in `router.dart`.
/// Paths are deep links the neighbor may see, so they stay in Spanish.
abstract final class Routes {
  static const home = '/';
  static const publish = '/publicar';
  static const publishForm = '/publicar/:tipo';
  static const toReview = '/por-revisar';
  static const emergency = '/emergencia';
  static const emergencyMap = '/emergencia/mapa';
  static const emergencyDashboard = '/emergencia/tablero';
  static const emergencyNeeds = '/emergencia/necesito';
  static const emergencyRequestForm = '/emergencia/nuevo/:need';
  static const emergencyRequest = '/emergencia/pedidos/:id';
  static const emergencyOffer = '/emergencia/ofrecer';
  static const emergencyResources = '/emergencia/recursos';
  static const emergencyContacts = '/cuenta/contactos-emergencia';
  static const map = '/mapa';
  static const tutorial = '/tutorial';
  static const signIn = '/ingresar';
  static const signInCode = '/ingresar/codigo';
  static const chooseZone = '/elegir-zona';
  static const account = '/cuenta';
  static const pushSettings = '/avisos';
  static const postDetail = '/publicaciones/:id';
  static const directory = '/servicios';
  static const serviceDetail = '/servicios/:id';
  static const serviceReview = '/servicios/:id/resena';
  static const providerProfile = '/proveedores/:id';
  static const publishService = '/publicar/servicio';
  static const editService = '/servicios/:id/editar';
  static const myData = '/cuenta/mis-datos';
  static const levels = '/cuenta/niveles';
  static const consent = '/consentimiento';
  static const changeZone = '/cuenta/cambiar-zona';
}
