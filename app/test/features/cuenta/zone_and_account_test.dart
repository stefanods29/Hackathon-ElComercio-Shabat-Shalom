import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/features/cuenta/data/http_auth_repository.dart';
import 'package:vecinal/features/cuenta/data/in_memory_auth_repository.dart';
import 'package:vecinal/features/cuenta/domain/account_use_cases.dart';
import 'package:vecinal/features/cuenta/domain/auth_repository.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 12);
  late Dio api;
  late InMemorySecureStore store;
  late HttpAuthRepository auth;
  late List<String> purged;
  late List<LocalUser> activated;
  late List<RequestOptions> requests;
  late Response<Object?> Function(RequestOptions) respond;
  late bool offline;

  Map<String, Object?> user(String zone) => {
    'id': 'neighbor-1',
    'nombreVisible': 'Vecino de prueba',
    'zonaId': zone,
  };

  Map<String, Object?> session() => {
    'tokenDeAcceso': 'access-1',
    'expiraEn': now.add(const Duration(minutes: 10)).toIso8601String(),
    'refreshToken': 'refresh-1',
    'refreshExpiraEn': now.add(const Duration(days: 7)).toIso8601String(),
    'usuario': user('zone-1'),
  };

  Response<Object?> answer(RequestOptions request, int status, Object? data) =>
      Response(requestOptions: request, statusCode: status, data: data);

  setUp(() async {
    purged = [];
    activated = [];
    requests = [];
    offline = false;
    store = InMemorySecureStore();
    api = createApiClient(
      const AppEnvironment(apiBaseUrl: 'https://api.example.test', powersyncUrl: ''),
      getToken: () async => null,
    );
    respond = (request) => answer(request, 200, session());
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          if (offline) {
            handler.reject(
              DioException(requestOptions: request, type: DioExceptionType.connectionError),
            );
          } else {
            handler.resolve(respond(request));
          }
        },
      ),
    );
    auth = HttpAuthRepository(
      api: api,
      store: store,
      clock: () => now,
      activate: (user) async => activated.add(user),
      purge: (id) async => purged.add(id),
    );
    addTearDown(() async {
      await auth.close();
      api.close();
    });
    await auth.verifyCode('+51900000002', '123456');
    requests.clear();
  });

  group('cambio de zona', () {
    test('usa PUT /v1/yo/zona y abre la cuenta con la zona nueva', () async {
      respond = (request) {
        expect(request.method, 'PUT');
        expect(request.path, '/v1/yo/zona');
        expect(request.data, {'zonaId': 'zone-2'});
        expect(request.headers['Idempotency-Key'], isA<String>());
        return answer(request, 200, {
          'tokenDeAcceso': 'access-2',
          'expiraEn': now.add(const Duration(minutes: 15)).toIso8601String(),
          'usuario': user('zone-2'),
        });
      };
      await auth.changeZone('zone-2');
      expect(activated.last.zoneId, 'zone-2');
      expect(
        await auth.watch().first,
        isA<SignedIn>().having((state) => state.user.zoneId, 'zona', 'zone-2'),
      );
      expect(await auth.getToken(), 'access-2');
      expect(purged, isEmpty);
    });

    test('elegir la zona que ya tiene no llama al servidor', () async {
      await auth.changeZone('zone-1');
      expect(requests, isEmpty);
    });

    test('un 409 cambio_de_zona_muy_pronto dice desde cuándo y no cambia nada', () async {
      respond = (request) => answer(request, 409, {
        'status': 409,
        'title': 'Todavía no puedes cambiar de zona',
        'codigo': 'cambio_de_zona_muy_pronto',
        'disponibleDesde': '2026-12-07T00:00:00Z',
      });
      await expectLater(
        auth.changeZone('zone-2'),
        throwsA(
          isA<ZoneChangeTooSoon>().having(
            (error) => error.availableFrom,
            'disponibleDesde',
            DateTime.utc(2026, 12, 7),
          ),
        ),
      );
      expect(activated.last.zoneId, 'zone-1');
      expect(purged, isEmpty);
      final firstKey = requests.single.headers['Idempotency-Key'];
      await expectLater(auth.changeZone('zone-2'), throwsA(isA<ZoneChangeTooSoon>()));
      expect(requests.last.headers['Idempotency-Key'], isNot(firstKey));
    });

    test('sin conexión explica que la necesita y no cambia nada', () async {
      offline = true;
      await expectLater(
        auth.changeZone('zone-2'),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'mensaje',
            'Necesitas conexión para cambiar de zona.',
          ),
        ),
      );
      expect(activated.last.zoneId, 'zone-1');
      expect(purged, isEmpty);
    });

    test('con dos acciones en la cola no cambia la zona', () async {
      final memory = InMemoryAuthRepository();
      addTearDown(memory.close);
      final change = ChangeZone(auth: memory, pendingUploads: () async => 2);
      await expectLater(
        change('zona-002'),
        throwsA(
          isA<PendingUploadsBlockZoneChange>().having(
            (error) => error.pendingUploads,
            'pendientes',
            2,
          ),
        ),
      );
      expect(
        await memory.watch().first,
        isA<SignedIn>().having((state) => state.user.zoneId, 'zona', isNull),
      );
    });

    test('con la cola vacía cambia la zona en el doble en memoria', () async {
      final memory = InMemoryAuthRepository();
      addTearDown(memory.close);
      await ChangeZone(auth: memory, pendingUploads: () async => 0)('zona-002');
      expect(
        await memory.watch().first,
        isA<SignedIn>().having((state) => state.user.zoneId, 'zona', 'zona-002'),
      );
    });
  });

  group('borrado de cuenta', () {
    test('con la confirmación del servidor borra la sesión y purga la cuenta', () async {
      respond = (request) {
        expect(request.method, 'DELETE');
        expect(request.path, '/v1/yo');
        expect(request.headers['Authorization'], 'Bearer access-1');
        return answer(request, 202, null);
      };
      await auth.deleteAccount();
      expect(purged, ['neighbor-1']);
      expect(await auth.watch().first, isA<SignedOut>());
      expect(await store.read(HttpAuthRepository.sessionKey), isNull);
      expect(await store.read(HttpAuthRepository.purgeKey), isNull);
    });

    test('sin conexión explica que la necesita y no borra nada', () async {
      offline = true;
      await expectLater(
        auth.deleteAccount(),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'mensaje',
            'Necesitas conexión para borrar tu cuenta.',
          ),
        ),
      );
      expect(purged, isEmpty);
      expect(await auth.watch().first, isA<SignedIn>());
      expect(await store.read(HttpAuthRepository.sessionKey), isNotNull);
    });

    test('un error del servidor tampoco borra nada', () async {
      respond = (request) => answer(request, 500, {'status': 500, 'title': 'Error interno'});
      await expectLater(auth.deleteAccount(), throwsA(isA<AuthFailure>()));
      expect(purged, isEmpty);
      expect(await store.read(HttpAuthRepository.sessionKey), isNotNull);
    });

    test('la baja de avisos espera como máximo su límite y luego borra la cuenta', () async {
      final memory = InMemoryAuthRepository();
      addTearDown(memory.close);
      final neverAnswers = Completer<void>();
      await DeleteAccount(
        auth: memory,
        unregisterPush: () => neverAnswers.future,
        pushLimit: const Duration(milliseconds: 20),
      )();
      expect(await memory.watch().first, isA<SignedOut>());
    });

    test('el doble en memoria también se niega sin conexión', () async {
      final memory = InMemoryAuthRepository()..offline = true;
      addTearDown(memory.close);
      await expectLater(memory.deleteAccount(), throwsA(isA<AuthFailure>()));
      expect(await memory.watch().first, isA<SignedIn>());
    });
  });
}
