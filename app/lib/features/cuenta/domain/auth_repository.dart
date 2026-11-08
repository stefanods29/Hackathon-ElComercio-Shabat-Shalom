import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/cuenta/domain/zone.dart';

/// Puerto de autenticación (Parte 5 del Lote D).
///
/// La implementación real llega con el Lote B (API `/v1/auth/*`, `/v1/zonas`).
/// Mientras tanto se usa el doble en `data/in_memory_auth_repository.dart`.
abstract interface class AuthRepository {
  /// Emite el estado de sesión cada vez que cambia.
  Stream<AuthState> watch();

  /// Solicita el código de verificación por SMS. Devuelve cuánto esperar antes
  /// de poder reenviar y cuándo vence el código actual.
  Future<CodeRequest> requestCode(String phone);

  /// Verifica el código de 6 dígitos.
  Future<void> verifyCode(String phone, String code);

  /// Lista las zonas disponibles para elegir.
  Future<List<Zone>> listZones();

  /// Asigna una zona al vecino autenticado.
  Future<void> chooseZone(String zoneId);

  /// Cierra la sesión del dispositivo actual y borra datos locales.
  Future<void> signOut();

  /// Cierra la sesión en todos los dispositivos (perdí mi teléfono).
  Future<void> signOutEverywhere();

  /// Cambia la zona de un vecino que ya tenía una (`PUT /v1/yo/zona`, contrato del Lote B).
  ///
  /// Lanza [ZoneChangeTooSoon] si el servidor responde 409 `cambio_de_zona_muy_pronto` y
  /// [AuthFailure] sin conexión. Con éxito, la app borra los datos de la zona anterior y
  /// sincroniza los de la nueva. Quien llama comprueba antes que la cola esté vacía
  /// (`ChangeZone`).
  Future<void> changeZone(String zoneId);

  /// Borra la cuenta en el servidor (`DELETE /v1/yo`) y, cuando lo confirma, todos los datos
  /// de la cuenta en el celular. Sin conexión lanza [AuthFailure] y no borra nada.
  Future<void> deleteAccount();
}

/// Respuesta de solicitud de código.
final class CodeRequest {
  const CodeRequest({required this.retryAfterSeconds, required this.expiresInSeconds});

  final int retryAfterSeconds;
  final int expiresInSeconds;
}

/// Errores tipados de autenticación.
///
/// [AuthFailure] lleva un mensaje listo para mostrar al vecino.
final class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

final class InvalidCode implements Exception {
  const InvalidCode();
}

/// 409 `cambio_de_zona_muy_pronto`: la zona se puede volver a cambiar desde [availableFrom].
final class ZoneChangeTooSoon implements Exception {
  const ZoneChangeTooSoon(this.availableFrom);

  /// Null si el servidor no informó la fecha.
  final DateTime? availableFrom;
}

/// Quedan acciones "Guardado en tu celular": deben enviarse antes de cambiar de zona, para que
/// ninguna se pierda ni llegue a la zona equivocada.
final class PendingUploadsBlockZoneChange implements Exception {
  const PendingUploadsBlockZoneChange(this.pendingUploads);

  final int pendingUploads;

  String get message =>
      'Tienes acciones guardadas en tu celular. Espera a que se envíen para cambiar de zona.';

  @override
  String toString() => message;
}

final class TooManyAttempts implements Exception {
  const TooManyAttempts(this.retryAfterSeconds);
  final int retryAfterSeconds;
}
