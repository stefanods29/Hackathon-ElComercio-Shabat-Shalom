import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/features/cuenta/domain/auth_repository.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/cuenta/domain/phone_verifier.dart';
import 'package:vecinal/features/cuenta/domain/zone.dart';

/// Owns the renewable session. Callers share a serialized rotation, including logout.
/// The API client passed here must not use getToken as its interceptor (recursion).
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    required this._api,
    required this._store,
    required this._activate,
    required this._purge,
    this._phoneVerifier,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const sessionKey = 'vecinal.auth.session';
  static const purgeKey = 'vecinal.auth.pending-purge';
  static const _zoneChoiceKey = 'vecinal.auth.zone-choice';
  final Dio _api;
  final SecureStore _store;
  final Future<void> Function(LocalUser) _activate;
  final Future<void> Function(String) _purge;

  /// With Firebase the SMS code is sent and checked outside the API (`PHONE_AUTH=firebase`).
  final PhoneVerifier? _phoneVerifier;
  final DateTime Function() _clock;
  final _changes = StreamController<AuthState>.broadcast();
  AuthState _state = const SignedOut();
  Map<String, Object?>? _session;
  Future<void> _pending = Future.value();
  bool _closed = false;

  Future<void> get whenIdle => _pending;

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Stream<AuthState> watch() => Stream.multi((listener) {
    final subscription = _changes.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
    listener.add(_state);
  });

  void _emit(AuthState state) {
    _state = state;
    if (!_changes.isClosed) _changes.add(state);
  }

  Future<void> initialize() => _serialize(() async {
    final interrupted = await _store.read(purgeKey);
    if (interrupted != null) {
      await _clear(interrupted);
      return;
    }
    final saved = await _store.read(sessionKey);
    if (saved == null) return;
    final data = Map<String, Object?>.from(jsonDecode(saved) as Map);
    _validate(data);
    _session = data;
    if (!DateTime.parse(data['refreshExpiraEn'] as String).isAfter(_clock())) {
      await _clear(_user(data).neighborId);
      return;
    }
    // Restoring the encrypted wall does not require a network connection.
    await _activateAndEmit(data);
  });

  @override
  Future<CodeRequest> requestCode(String phone) async {
    final verifier = _phoneVerifier;
    if (verifier != null) {
      // Android may verify the phone by itself; the router then leaves the code page.
      return verifier.sendCode(
        _phone(phone),
        onVerified: (token) => unawaited(_signInWithFirebase(token).catchError((Object _) {})),
      );
    }
    final response = await _api.post<Object?>('/v1/auth/otp', data: {'telefono': _phone(phone)});
    _require(response, 202);
    final body = response.data as Map;
    return CodeRequest(
      retryAfterSeconds: body['reintentarEnSegundos'] as int,
      expiresInSeconds: body['expiraEnSegundos'] as int,
    );
  }

  @override
  Future<void> verifyCode(String phone, String code) async {
    final verifier = _phoneVerifier;
    if (verifier != null) return _signInWithFirebase(await verifier.tokenFor(code));
    final body = {'telefono': _phone(phone), 'codigo': code};
    return _signIn(() => _api.post<Object?>('/v1/auth/otp/verificar', data: body));
  }

  /// The automatic verification and the typed code may both arrive: only one opens a session.
  Future<void> _signInWithFirebase(String token) {
    final body = {'tokenFirebase': token};
    return _signIn(() => _api.post<Object?>('/v1/auth/firebase', data: body), once: true);
  }

  Future<void> _signIn(Future<Response<Object?>> Function() request, {bool once = false}) {
    return _serialize(() async {
      if (_closed) throw const AuthFailure('La sesión ya está cerrada.');
      if (once && _session != null) return;
      final interrupted = await _store.read(purgeKey);
      if (interrupted != null) await _clear(interrupted);
      final response = await request();
      if (response.statusCode == 401) throw const InvalidCode();
      _require(response, 200);
      await _save(response.data);
      await _activateAndEmit(_session!);
    });
  }

  @override
  Future<List<Zone>> listZones() async {
    final response = await _api.get<Object?>('/v1/zonas');
    _require(response, 200);
    return (response.data as List)
        .map(
          (row) => Zone(
            id: (row as Map)['id'] as String,
            name: row['nombre'] as String,
            district: row['distrito'] as String,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> chooseZone(String zoneId) =>
      _serialize(() => _putZone(zoneId, noSession: 'Vuelve a ingresar para elegir tu zona.'));

  /// Same route as [chooseZone] for a neighbor who already has a zone (Lot B contract). The new
  /// access token carries the new zone, so `activate` purges and reopens the account database.
  @override
  Future<void> changeZone(String zoneId) => _serialize(() async {
    final session = _session;
    if (session == null) throw const AuthFailure('Vuelve a ingresar para cambiar de zona.');
    if (_user(session).zoneId == zoneId) return;
    try {
      await _putZone(zoneId, noSession: 'Vuelve a ingresar para cambiar de zona.');
    } on DioException {
      throw const AuthFailure('Necesitas conexión para cambiar de zona.');
    }
  });

  Future<void> _putZone(String zoneId, {required String noSession}) async {
    final token = await _getToken();
    if (token == null) throw AuthFailure(noSession);
    final accountId = _user(_session!).neighborId;
    final savedChoice = await _store.read(_zoneChoiceKey);
    final choice = savedChoice == null ? null : jsonDecode(savedChoice) as Map;
    final key = choice?['accountId'] == accountId && choice?['zoneId'] == zoneId
        ? choice!['key'] as String
        : const Uuid().v4();
    await _store.write(
      _zoneChoiceKey,
      jsonEncode({'accountId': accountId, 'zoneId': zoneId, 'key': key}),
    );
    final response = await _api.put<Object?>(
      '/v1/yo/zona',
      data: {'zonaId': zoneId},
      options: Options(headers: {'Authorization': 'Bearer $token', 'Idempotency-Key': key}),
    );
    if (response.statusCode == 401) await _rejectSession(_session!);
    final body = response.data;
    if (response.statusCode == 409 &&
        body is Map &&
        body['codigo'] == 'cambio_de_zona_muy_pronto') {
      // The server would replay this stored 409 for the same key: the next attempt uses a new one.
      await _store.delete(_zoneChoiceKey);
      final availableFrom = body['disponibleDesde'];
      throw ZoneChangeTooSoon(availableFrom is String ? DateTime.tryParse(availableFrom) : null);
    }
    _require(response, 200);
    // This endpoint issues access credentials only; retain the current refresh token.
    await _save({..._session!, ...Map<String, Object?>.from(response.data as Map)});
    await _store.delete(_zoneChoiceKey);
    await _activateAndEmit(_session!);
  }

  Future<String?> getToken() => _serialize(_getToken);

  Future<String?> _getToken() async {
    final session = _session;
    if (_closed || session == null) return null;
    final expiry = DateTime.parse(session['expiraEn'] as String);
    if (expiry.isAfter(_clock().add(const Duration(seconds: 60)))) {
      return session['tokenDeAcceso'] as String;
    }
    final response = await _api.post<Object?>(
      '/v1/auth/refrescar',
      data: {'refreshToken': session['refreshToken']},
    );
    if (response.statusCode == 401) {
      // Do not await engine disconnection here: it may itself be waiting on getToken.
      await _rejectSession(session);
      return null;
    }
    _require(response, 200);
    await _save(response.data);
    return _session!['tokenDeAcceso'] as String;
  }

  /// Safe as a connector callback: queues purging after the current credential request.
  Future<void> revokeSession() => _serialize(() async {
    final session = _session;
    if (session != null) await _clear(_user(session).neighborId);
  });

  Future<void> _rejectSession(Map<String, Object?> session) async {
    final accountId = _user(session).neighborId;
    await _store.write(purgeKey, accountId);
    _session = null;
    _emit(const SignedOut());
    unawaited(_serialize(() => _clear(accountId)));
  }

  @override
  Future<void> signOut() => _serialize(() async {
    final session = _session;
    if (session == null) return;
    try {
      final token = await _getToken();
      if (token != null) {
        await _api.post<Object?>(
          '/v1/auth/cerrar-sesion',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }
    } catch (_) {
      // Local logout remains available offline. Global revocation requires the server.
    }
    await _clear(_user(session).neighborId);
  });

  @override
  Future<void> signOutEverywhere() => _serialize(() async {
    final session = _session;
    if (session == null) return;
    final token = await _getToken();
    if (token == null) throw const AuthFailure('No se pudo revocar las otras sesiones.');
    final response = await _api.post<Object?>(
      '/v1/auth/sesiones/revocar',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    _require(response, 204);
    await _clear(_user(session).neighborId);
  });

  /// Deletes the account on the server and, once it confirms (202), everything on the phone.
  /// Without a connection nothing is deleted yet.
  @override
  Future<void> deleteAccount() => _serialize(() async {
    final session = _session;
    if (session == null) return;
    final response = await _requestDeletion();
    if (response.statusCode == 401) {
      await _rejectSession(session);
      throw const AuthFailure(_signInToDelete);
    }
    if (response.statusCode != 202 && response.statusCode != 204) _require(response, 202);
    await _clear(_user(session).neighborId);
  });

  static const _signInToDelete = 'Vuelve a ingresar para borrar tu cuenta.';

  Future<Response<Object?>> _requestDeletion() async {
    try {
      final token = await _getToken();
      if (token == null) throw const AuthFailure(_signInToDelete);
      final response = await _api.delete<Object?>(
        '/v1/yo',
        options: Options(
          headers: {'Authorization': 'Bearer $token', 'Idempotency-Key': const Uuid().v4()},
        ),
      );
      return response;
    } on DioException {
      throw const AuthFailure('Necesitas conexión para borrar tu cuenta.');
    }
  }

  Future<void> _clear(String accountId) async {
    await _store.write(purgeKey, accountId);
    _session = null;
    _emit(const SignedOut());
    await _store.delete(sessionKey);
    await _store.delete(_zoneChoiceKey);
    await _purge(accountId);
    await _store.delete(purgeKey);
  }

  Future<void> _save(Object? value) async {
    final session = Map<String, Object?>.from(value as Map);
    _validate(session);
    // A single secure entry prevents mixed access and refresh generations on restart.
    await _store.write(sessionKey, jsonEncode(session));
    _session = session;
  }

  Future<void> _activateAndEmit(Map<String, Object?> session) async {
    final user = _user(session);
    if (user.zoneId == null) {
      _emit(NeedsZone(user));
    } else {
      await _activate(user);
      _emit(SignedIn(user));
    }
  }

  static LocalUser _user(Map<String, Object?> session) {
    final row = session['usuario'] as Map;
    return LocalUser(
      neighborId: row['id'] as String,
      displayName: row['nombreVisible'] as String,
      zoneId: row['zonaId'] as String?,
    );
  }

  static void _validate(Map<String, Object?> session) {
    for (final key in ['tokenDeAcceso', 'refreshToken', 'expiraEn', 'refreshExpiraEn']) {
      if (session[key] is! String || (session[key] as String).isEmpty) {
        throw const FormatException('Respuesta de sesión inválida.');
      }
    }
    DateTime.parse(session['expiraEn'] as String);
    DateTime.parse(session['refreshExpiraEn'] as String);
    _user(session);
  }

  static String _phone(String phone) => '+${phone.replaceAll(RegExp(r'[^0-9]'), '')}';

  static void _require(Response<Object?> response, int expected) {
    if (response.statusCode == expected) return;
    if (response.statusCode == 429) {
      final body = response.data;
      final seconds = body is Map ? body['reintentarEnSegundos'] : null;
      throw TooManyAttempts(
        seconds is num
            ? seconds.ceil()
            : int.tryParse(response.headers.value('Retry-After') ?? '') ?? 60,
      );
    }
    throw const AuthFailure('No se pudo completar. Revisa tu conexión e intenta de nuevo.');
  }

  Future<void> close() async {
    await _pending;
    _closed = true;
    await _changes.close();
  }
}
