import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';

void main() {
  late Dio api;

  setUp(() {
    api = createApiClient(
      const AppEnvironment(apiBaseUrl: 'https://api.example.test', powersyncUrl: ''),
      getToken: () async => 'access-token',
    );
    addTearDown(api.close);
  });

  void respond(int status, Object data) {
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          expect(request.method, 'GET');
          expect(request.path, '/v1/sync/credenciales');
          expect(request.headers['Authorization'], 'Bearer access-token');
          handler.resolve(Response(requestOptions: request, statusCode: status, data: data));
        },
      ),
    );
  }

  test('solicita credenciales nuevas al recibir la orden de refresco del SDK', () async {
    var requests = 0;
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          expect(request.path, '/v1/sync/credenciales');
          expect(request.headers['Authorization'], 'Bearer access-token');
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'endpoint': 'https://sync.example.test',
                'token': 'sync-token-${++requests}',
                'expiraEn': '2026-11-07T07:10:00Z',
              },
            ),
          );
        },
      ),
    );
    final connector = VecinalConnector(api, clock: () => DateTime.utc(2026, 11, 7, 7));
    final first = await connector.getCredentialsCached();
    expect(first!.endpoint, 'https://sync.example.test');
    expect(first.expiresAt, DateTime.utc(2026, 11, 7, 7, 10));
    final next = await connector.prefetchCredentials();
    expect(next!.token, 'sync-token-2');
    expect(await connector.getCredentialsCached(), same(next));
  });

  test('reconoce la revocación explícita sin tratar cualquier 401 como revocación', () async {
    respond(401, {'codigo': 'sesion_revocada'});
    var revoked = false;
    final connector = VecinalConnector(api, onSessionRevoked: () => revoked = true);
    await expectLater(
      connector.fetchCredentials(),
      throwsA(isA<SyncCredentialsFailure>().having((e) => e.sessionRevoked, 'revocada', isTrue)),
    );
    expect(revoked, isTrue);
  });

  test('pide nuevas credenciales automáticamente antes de vencer', () async {
    var requests = 0;
    final refreshed = Completer<void>();
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          final lifetime = ++requests == 1
              ? const Duration(milliseconds: 100)
              : const Duration(minutes: 10);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'endpoint': 'https://sync.example.test',
                'token': 'sync-token-$requests',
                'expiraEn': DateTime.now().add(lifetime).toIso8601String(),
              },
            ),
          );
          if (requests == 2) refreshed.complete();
        },
      ),
    );
    final connector = VecinalConnector(api)..startRefreshing();
    addTearDown(connector.stopRefreshing);
    await connector.getCredentialsCached();
    await refreshed.future.timeout(const Duration(seconds: 3));
  });

  test('propaga una falla de red para que PowerSync vuelva a intentar', () async {
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.reject(
            DioException(requestOptions: request, type: DioExceptionType.connectionError),
          );
        },
      ),
    );
    final connector = VecinalConnector(api, onSessionRevoked: () => fail('Sesión no revocada'));
    await expectLater(connector.fetchCredentials(), throwsA(isA<DioException>()));
  });
}
