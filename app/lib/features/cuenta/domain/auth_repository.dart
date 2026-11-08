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

/// Optional A4 capability. Existing authentication implementations stay source compatible.
abstract interface class AccountLifecycle {
  /// Completes only after server acknowledgement and the implementation's safe local purge.
  Future<void> deleteAccount();

  /// Checks outstanding commands and replaces the zone's local data after acknowledgement.
  Future<void> changeZone(String zoneId);
}

extension AuthAccountLifecycle on AuthRepository {
  bool get supportsAccountLifecycle => this is AccountLifecycle;
  Future<void> deleteAccount() {
    final repository = this;
    if (repository is AccountLifecycle) return repository.deleteAccount();
    throw const AccountCapabilityUnavailable();
  }

  Future<void> changeZone(String zoneId) {
    final repository = this;
    if (repository is AccountLifecycle) return repository.changeZone(zoneId);
    throw const AccountCapabilityUnavailable();
  }
}

class AccountCapabilityUnavailable implements Exception {
  const AccountCapabilityUnavailable();
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

final class TooManyAttempts implements Exception {
  const TooManyAttempts(this.retryAfterSeconds);
  final int retryAfterSeconds;
}
