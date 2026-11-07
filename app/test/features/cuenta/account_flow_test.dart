import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/features/cuenta/data/http_auth_repository.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';

void main() {
  testWidgets('teléfono → código recibido por ruta → muro; fallo de red permite reintentar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var attempts = 0;
    final api = createApiClient(
      const AppEnvironment(apiBaseUrl: 'https://api.example.test', powersyncUrl: ''),
      getToken: () async => null,
    );
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, handler) {
          final body = r.data as Map;
          expect(body['telefono'], '+51900000002');
          if (r.path == '/v1/auth/otp') {
            handler.resolve(
              Response(
                requestOptions: r,
                statusCode: 202,
                data: {'reintentarEnSegundos': 45, 'expiraEnSegundos': 300},
              ),
            );
          } else if (++attempts == 1) {
            handler.resolve(Response(requestOptions: r, statusCode: 503, data: {}));
          } else {
            expect(body['codigo'], '123456');
            handler.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: {
                  'tokenDeAcceso': 'access',
                  'expiraEn': '2030-01-01T00:00:00Z',
                  'refreshToken': 'refresh',
                  'refreshExpiraEn': '2030-02-01T00:00:00Z',
                  'usuario': {
                    'id': 'neighbor',
                    'nombreVisible': 'Vecino de prueba',
                    'zonaId': 'zone',
                  },
                },
              ),
            );
          }
        },
      ),
    );
    final auth = HttpAuthRepository(
      api: api,
      store: InMemorySecureStore(),
      activate: (_) async {},
      purge: (_) async {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const VecinalApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ingresar a Vecinal'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '900 000 002');
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();
    expect(find.textContaining('+51900000002'), findsOneWidget);
    expect(find.text('Reenviar código en 45 s'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Verificar código'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo verificar.'), findsWidgets);
    await tester.tap(find.text('Verificar código'));
    await tester.pumpAndSettle();
    expect(find.text('Muro de favores'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await auth.close();
    api.close();
  });
}
