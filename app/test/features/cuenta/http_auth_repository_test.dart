import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/features/cuenta/data/http_auth_repository.dart';
import 'package:vecinal/features/cuenta/domain/auth_repository.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/cuenta/domain/phone_verifier.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 12);
  late DateTime clock;
  late Dio api;
  late InMemorySecureStore store;
  late HttpAuthRepository auth;
  late List<String> purged;
  late List<LocalUser> activated;
  late Future<Response<Object?>> Function(RequestOptions) respond;

  Map<String, Object?> session({String token = 'access-1', String? zone = 'zone-1'}) => {
    'tokenDeAcceso': token,
    'expiraEn': clock.add(const Duration(minutes: 10)).toIso8601String(),
    'refreshToken': 'refresh-$token',
    'refreshExpiraEn': now.add(const Duration(days: 7)).toIso8601String(),
    'usuario': {'id': 'neighbor-1', 'nombreVisible': 'Vecino de prueba', 'zonaId': zone},
  };

  Response<Object?> answer(RequestOptions request, int status, Object? data) =>
      Response(requestOptions: request, statusCode: status, data: data);

  HttpAuthRepository withVerifier(PhoneVerifier verifier) {
    final repository = HttpAuthRepository(
      api: api,
      store: store,
      clock: () => clock,
      activate: (user) async => activated.add(user),
      purge: (id) async => purged.add(id),
      phoneVerifier: verifier,
    );
    addTearDown(repository.close);
    return repository;
  }

  setUp(() {
    clock = now;
    purged = [];
    activated = [];
    store = InMemorySecureStore();
    api = createApiClient(
      const AppEnvironment(apiBaseUrl: 'https://api.example.test', powersyncUrl: ''),
      getToken: () async => null,
    );
    respond = (request) async => answer(request, 200, session());
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          handler.resolve(await respond(request));
        },
      ),
    );
    auth = HttpAuthRepository(
      api: api,
      store: store,
      clock: () => clock,
      activate: (user) async => activated.add(user),
      purge: (id) async => purged.add(id),
    );
    addTearDown(() async {
      await auth.close();
      api.close();
    });
  });

  test('OTP normaliza teléfono y conserva el plazo del servidor', () async {
    respond = (r) async {
      expect(r.path, '/v1/auth/otp');
      expect(r.data, {'telefono': '+51900000002'});
      return answer(r, 202, {'reintentarEnSegundos': 45, 'expiraEnSegundos': 300});
    };
    final request = await auth.requestCode('+51 900 000 002');
    expect(request.retryAfterSeconds, 45);
    expect(request.expiresInSeconds, 300);
  });

  test('guarda la sesión completa antes de activar la cuenta y restaura sin red', () async {
    await auth.verifyCode('+51900000002', '123456');
    expect(await auth.watch().first, isA<SignedIn>());
    final saved = await store.read(HttpAuthRepository.sessionKey);
    expect((jsonDecode(saved!) as Map)['refreshToken'], 'refresh-access-1');
    expect(activated.single.zoneId, 'zone-1');
    await auth.close();
    auth = HttpAuthRepository(
      api: api,
      store: store,
      clock: () => clock,
      activate: (user) async => activated.add(user),
      purge: (id) async => purged.add(id),
    );
    respond = (r) => throw StateError('No debe necesitar red al restaurar');
    await auth.initialize();
    expect(await auth.getToken(), 'access-1');
    expect(activated.length, 2);
  });

  test('20 renovaciones concurrentes rotan una sola vez y persisten el refresh nuevo', () async {
    await auth.verifyCode('+51900000002', '123456');
    clock = now.add(const Duration(minutes: 10));
    var requests = 0;
    respond = (r) async {
      expect(r.path, '/v1/auth/refrescar');
      expect(r.data, {'refreshToken': 'refresh-access-1'});
      requests++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return answer(r, 200, session(token: 'access-2'));
    };
    final tokens = await Future.wait(List.generate(20, (_) => auth.getToken()));
    expect(tokens, everyElement('access-2'));
    expect(requests, 1);
    expect(
      (jsonDecode((await store.read(HttpAuthRepository.sessionKey))!) as Map)['refreshToken'],
      'refresh-access-2',
    );
  });

  test('elegir zona conserva el refresh y lleva clave de idempotencia', () async {
    respond = (r) async => answer(r, 200, session(zone: null));
    await auth.verifyCode('+51900000002', '123456');
    expect(await auth.watch().first, isA<NeedsZone>());
    expect(activated, isEmpty);
    respond = (r) async {
      expect(r.method, 'PUT');
      expect(r.headers['Authorization'], 'Bearer access-1');
      expect(r.headers['Idempotency-Key'], isNotEmpty);
      final result = session()
        ..remove('refreshToken')
        ..remove('refreshExpiraEn');
      return answer(r, 200, result);
    };
    await auth.chooseZone('zone-1');
    expect(await auth.watch().first, isA<SignedIn>());
    expect(
      (jsonDecode((await store.read(HttpAuthRepository.sessionKey))!) as Map)['refreshToken'],
      'refresh-access-1',
    );
  });

  test(
    'cierre sin red borra tokens y bases; revocar todos exige confirmación del servidor',
    () async {
      await auth.verifyCode('+51900000002', '123456');
      respond = (r) async => answer(r, 503, {});
      await expectLater(auth.signOutEverywhere(), throwsA(isA<AuthFailure>()));
      expect(purged, isEmpty);
      expect(await auth.watch().first, isA<SignedIn>());
      await auth.signOut();
      expect(purged, ['neighbor-1']);
      expect(await store.read(HttpAuthRepository.sessionKey), isNull);
      expect(await auth.getToken(), isNull);
      expect(await auth.watch().first, isA<SignedOut>());
    },
  );

  test('401 al renovar libera getToken antes de purgar el motor que lo está esperando', () async {
    await auth.verifyCode('+51900000002', '123456');
    clock = now.add(const Duration(minutes: 10));
    var requests = 0;
    respond = (r) async {
      requests++;
      return answer(r, 401, {'codigo': 'sesion_revocada'});
    };
    expect(
      await Future.wait(
        List.generate(20, (_) => auth.getToken()),
      ).timeout(const Duration(seconds: 2)),
      everyElement(isNull),
    );
    await auth.whenIdle;
    expect(requests, 1);
    expect(purged, ['neighbor-1']);
    expect(await store.read(HttpAuthRepository.sessionKey), isNull);
  });

  test('reanudar un cierre interrumpido termina la purga antes de abrir otra sesión', () async {
    await auth.verifyCode('+51900000002', '123456');
    await store.write(HttpAuthRepository.purgeKey, 'neighbor-1');
    await auth.close();
    activated.clear();
    auth = HttpAuthRepository(
      api: api,
      store: store,
      clock: () => clock,
      activate: (user) async => activated.add(user),
      purge: (id) async => purged.add(id),
    );
    await auth.initialize();
    expect(purged, ['neighbor-1']);
    expect(activated, isEmpty);
    expect(await store.read(HttpAuthRepository.sessionKey), isNull);
  });

  test('errores de código y límite se traducen para las pantallas', () async {
    respond = (r) async => answer(r, 401, {'codigo': 'codigo_invalido'});
    await expectLater(auth.verifyCode('+51900000002', '111111'), throwsA(isA<InvalidCode>()));
    respond = (r) async => answer(r, 429, {'reintentarEnSegundos': 120});
    await expectLater(
      auth.requestCode('+51900000002'),
      throwsA(isA<TooManyAttempts>().having((e) => e.retryAfterSeconds, 'espera', 120)),
    );
  });

  test('elegir zona conserva la misma clave tras un fallo de red y un reinicio', () async {
    respond = (r) async => answer(r, 200, session(zone: null));
    await auth.verifyCode('+51900000002', '123456');
    String? key;
    respond = (r) async {
      key = r.headers['Idempotency-Key'] as String;
      return answer(r, 503, {});
    };
    await expectLater(auth.chooseZone('zone-1'), throwsA(isA<AuthFailure>()));
    await auth.close();
    auth = HttpAuthRepository(
      api: api,
      store: store,
      clock: () => clock,
      activate: (user) async => activated.add(user),
      purge: (id) async => purged.add(id),
    );
    await auth.initialize();
    respond = (r) async {
      expect(r.headers['Idempotency-Key'], key);
      return answer(r, 200, session());
    };
    await auth.chooseZone('zone-1');
    expect(await auth.watch().first, isA<SignedIn>());
  });

  test('revocación al elegir zona vuelve al ingreso aunque todavía no exista motor sync', () async {
    respond = (r) async => answer(r, 200, session(zone: null));
    await auth.verifyCode('+51900000002', '123456');
    respond = (r) async => answer(r, 401, {'codigo': 'sesion_revocada'});
    await expectLater(auth.chooseZone('zone-1'), throwsA(isA<AuthFailure>()));
    await auth.whenIdle;
    expect(await auth.watch().first, isA<SignedOut>());
    expect(purged, ['neighbor-1']);
    expect(await store.read(HttpAuthRepository.sessionKey), isNull);
    expect(await auth.getToken(), isNull);
  });

  test('con Firebase la API solo recibe el token del teléfono ya verificado', () async {
    final verifier = _FakePhoneVerifier();
    final firebase = withVerifier(verifier);
    final paths = <String>[];
    respond = (r) async {
      paths.add(r.path);
      expect(r.data, {'tokenFirebase': 'token-firebase'});
      return answer(r, 200, session());
    };
    final request = await firebase.requestCode('+51 900 000 002');
    expect(verifier.phones, ['+51900000002']);
    expect(request.retryAfterSeconds, 60);
    await expectLater(firebase.verifyCode('+51900000002', '111111'), throwsA(isA<InvalidCode>()));
    expect(paths, isEmpty);
    await firebase.verifyCode('+51900000002', '123456');
    expect(paths, ['/v1/auth/firebase']);
    expect(await firebase.watch().first, isA<SignedIn>());
    expect(activated.single.zoneId, 'zone-1');
  });

  test('un token que la API rechaza se muestra como código vencido', () async {
    final firebase = withVerifier(_FakePhoneVerifier());
    respond = (r) async => answer(r, 401, {'codigo': 'token_firebase_invalido'});
    await firebase.requestCode('+51900000002');
    await expectLater(firebase.verifyCode('+51900000002', '123456'), throwsA(isA<InvalidCode>()));
    expect(activated, isEmpty);
    expect(await store.read(HttpAuthRepository.sessionKey), isNull);
  });

  test('la verificación automática y el código escrito abren una sola sesión', () async {
    final verifier = _FakePhoneVerifier();
    final firebase = withVerifier(verifier);
    var requests = 0;
    respond = (r) async {
      requests++;
      return answer(r, 200, session());
    };
    await firebase.requestCode('+51900000002');
    verifier.verifiedAutomatically('token-firebase');
    await firebase.verifyCode('+51900000002', '123456');
    expect(requests, 1);
    expect(await firebase.watch().first, isA<SignedIn>());
    expect(activated, hasLength(1));
  });
}

/// Firebase double: `123456` is the only right code.
class _FakePhoneVerifier implements PhoneVerifier {
  final phones = <String>[];
  void Function(String token)? _onVerified;

  void verifiedAutomatically(String token) => _onVerified?.call(token);

  @override
  Future<CodeRequest> sendCode(String phone, {void Function(String token)? onVerified}) async {
    phones.add(phone);
    _onVerified = onVerified;
    return const CodeRequest(retryAfterSeconds: 60, expiresInSeconds: 300);
  }

  @override
  Future<String> tokenFor(String code) async {
    if (code != '123456') throw const InvalidCode();
    return 'token-firebase';
  }
}
