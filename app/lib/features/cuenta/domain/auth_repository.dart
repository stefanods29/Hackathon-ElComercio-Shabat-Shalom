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
}

/// Respuesta de solicitud de código.
final class CodeRequest {
  const CodeRequest({required this.retryAfterSeconds, required this.expiresInSeconds});

  final int retryAfterSeconds;
  final int expiresInSeconds;
}

/// Errores tipados de autenticación.
final class InvalidCode implements Exception {
  const InvalidCode();
}

final class TooManyAttempts implements Exception {
  const TooManyAttempts(this.retryAfterSeconds);
  final int retryAfterSeconds;
}
