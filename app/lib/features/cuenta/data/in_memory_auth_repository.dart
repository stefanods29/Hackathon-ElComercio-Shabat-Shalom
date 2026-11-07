import 'dart:async';

import 'package:vecinal/features/cuenta/domain/auth_repository.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/cuenta/domain/zone.dart';

/// Doble en memoria de `AuthRepository` para desarrollar en paralelo con el Lote B.
///
/// Por defecto arranca en `SignedIn` con la sesión de demostración (Beto, zona piloto)
/// para que el resto de la app y las pruebas actuales sigan igual. Las pruebas de este
/// flujo lo crean en `SignedOut`.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({this.startSignedOut = false}) {
    if (startSignedOut) {
      _state = const SignedOut();
    } else {
      _state = SignedIn(const LocalUser(
        neighborId: '01970000-0000-7000-8000-0000000000b1',
        displayName: 'Beto (vecino)',
      ));
    }
  }

  final bool startSignedOut;
  AuthState _state = const SignedOut();
  final _controller = StreamController<AuthState>();

  int _failedAttempts = 0;
  static const _maxAttempts = 5;

  static const _correctCode = '123456';

  final _zones = const [
    Zone(id: 'zona-001', name: 'Piloto', district: 'Lima'),
    Zone(id: 'zona-002', name: 'Centro', district: 'Lima'),
    Zone(id: 'zona-003', name: 'Miraflores', district: 'Lima'),
  ];

  @override
  Stream<AuthState> watch() async* {
    yield _state;
    yield* _controller.stream;
  }

  @override
  Future<CodeRequest> requestCode(String phone) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_failedAttempts >= _maxAttempts) {
      return const CodeRequest(retryAfterSeconds: 900, expiresInSeconds: 300);
    }
    return const CodeRequest(retryAfterSeconds: 30, expiresInSeconds: 300);
  }

  @override
  Future<void> verifyCode(String phone, String code) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (_failedAttempts >= _maxAttempts) {
      throw const TooManyAttempts(900);
    }

    if (code != _correctCode) {
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        throw const TooManyAttempts(900);
      }
      throw const InvalidCode();
    }

    _failedAttempts = 0;
    _state = const SignedIn(LocalUser(
      neighborId: '01970000-0000-7000-8000-0000000000b1',
      displayName: 'Beto (vecino)',
    ));
    _controller.add(_state);
  }

  @override
  Future<List<Zone>> listZones() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_zones);
  }

  @override
  Future<void> chooseZone(String zoneId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _zones.firstWhere((z) => z.id == zoneId, orElse: () => throw ArgumentError('Zona no encontrada'));
    _state = const SignedIn(LocalUser(
      neighborId: '01970000-0000-7000-8000-8000-0000000000b1',
      displayName: 'Beto (vecino)',
    ));
    _controller.add(_state);
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _state = const SignedOut();
    _controller.add(_state);
  }

  @override
  Future<void> signOutEverywhere() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _state = const SignedOut();
    _controller.add(_state);
  }

  void close() {
    _controller.close();
  }
}
