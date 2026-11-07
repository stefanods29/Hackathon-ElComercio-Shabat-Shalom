import 'package:dio/dio.dart';
import 'package:vecinal/core/di/providers.dart';

/// Uses the seeded Beto account while the OTP endpoints and screens are being built.
class DevSyncSession {
  DevSyncSession(this._api);

  final Dio _api;
  ({String token, DateTime expiresAt})? _session;
  Future<String>? _renewal;

  Future<String> getToken() async {
    final session = _session;
    if (session != null &&
        session.expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return session.token;
    }
    return _renewal ??= _signIn().whenComplete(() => _renewal = null);
  }

  Future<String> _signIn() async {
    final response = await _api.post<Object?>(
      '/v1/dev/sesiones',
      data: {'telefono': '+51900000002'},
    );
    final data = response.data;
    if (response.statusCode != 201 || data is! Map<String, Object?>) {
      throw StateError('Sesión de desarrollo no disponible (${response.statusCode}).');
    }
    final user = data['usuario'];
    final token = data['tokenDeAcceso'];
    final expiry = data['expiraEn'];
    final expiresAt = expiry is String ? DateTime.tryParse(expiry) : null;
    if (user is! Map<String, Object?> ||
        user['id'] != LocalSession.demo.neighborId ||
        user['zonaId'] != LocalSession.demo.zoneId ||
        token is! String ||
        token.isEmpty ||
        expiresAt == null) {
      throw const FormatException('Sesión de desarrollo inválida.');
    }
    _session = (token: token, expiresAt: expiresAt);
    return token;
  }
}
