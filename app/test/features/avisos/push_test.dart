import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/features/avisos/data/api_push_registration.dart';
import 'package:vecinal/features/avisos/data/providers.dart';
import 'package:vecinal/features/avisos/data/push_service.dart';
import 'package:vecinal/features/avisos/domain/notification_route.dart';
import 'package:vecinal/features/avisos/domain/push_platform.dart';
import 'package:vecinal/features/avisos/domain/push_registration.dart';
import 'package:vecinal/features/avisos/presentation/push_settings_page.dart';
import 'package:vecinal/features/solidaridad/presentation/post_detail_page.dart';
import 'package:vecinal/l10n/app_localizations.dart';

const _post = '01970000-0000-7000-8000-00000000f001';
const _zone = '01970000-0000-7000-8000-000000000001';
const _credentials = PushCredentials(userId: 'ana', zoneId: _zone, accessToken: 'jwt-de-prueba');
const _message = {'tipo': 'favor_tomado', 'publicacionId': _post};

class _Platform implements PushPlatform {
  final tokens = StreamController<String>.broadcast(sync: true);
  final opened = StreamController<Map<String, String>>.broadcast(sync: true);
  final foreground = StreamController<Map<String, String>>.broadcast(sync: true);
  final topics = <String>[];
  final removed = <String>[];
  PushPermission allowed = PushPermission.allowed;
  String currentToken = 'token-1';
  Map<String, String>? initial;
  int deleted = 0;
  @override
  String get devicePlatform => 'android';
  @override
  Future<void> initialize() async {}
  @override
  Future<PushPermission> permission({bool request = false}) async => allowed;
  @override
  Future<String?> token() async => currentToken;
  @override
  Future<void> deleteToken() async {
    deleted++;
  }

  @override
  Future<void> subscribe(String topic) async {
    topics.add(topic);
  }

  @override
  Future<void> unsubscribe(String topic) async {
    removed.add(topic);
  }

  @override
  Future<Map<String, String>?> initialMessage() async => initial;
  @override
  Stream<String> get tokenChanges => tokens.stream;
  @override
  Stream<Map<String, String>> get openedMessages => opened.stream;
  @override
  Stream<Map<String, String>> get foregroundMessages => foreground.stream;
  Future<void> close() async {
    await tokens.close();
    await opened.close();
    await foreground.close();
  }
}

class _Registration implements PushRegistration {
  final registered = <String>[];
  final removed = <String>[];
  bool connected = true;
  @override
  Future<bool> register(String token, String platform) async {
    registered.add(token);
    return connected;
  }

  @override
  Future<bool> unregister(String token) async {
    removed.add(token);
    return connected;
  }

  @override
  Future<bool> retry() async => connected;
}

class _FixedStatus extends PushController {
  @override
  PushStatus build() => PushStatus.denied;
}

void main() {
  test('routeFor solo acepta tipos conocidos e ids completos', () {
    expect(routeFor(_message), '/publicaciones/$_post');
    for (final data in [
      <String, String>{},
      {'tipo': 'desconocido', 'publicacionId': _post},
      {'tipo': 'favor_tomado', 'publicacionId': '../../configuracion'},
      {'tipo': 'favor_tomado', 'publicacionId': 'https://example.com'},
    ]) {
      expect(routeFor(data), isNull);
    }
  });

  group('servicio con Firebase falso', () {
    late _Platform platform;
    late _Registration registration;
    late PushService service;
    late InMemorySecureStore store;
    late List<PushStatus> statuses;
    late List<String> routes;
    setUp(() {
      platform = _Platform();
      registration = _Registration();
      store = InMemorySecureStore();
      statuses = [];
      routes = [];
      service = PushService(
        platform: platform,
        store: store,
        registrationFor: (_) => registration,
        onStatus: statuses.add,
        navigate: routes.add,
        onForeground: (_) {},
      );
    });
    tearDown(() async {
      await service.dispose();
      await platform.close();
    });

    test('registra, refresca, cambia de zona y da de baja al salir', () async {
      await service.start(_credentials);
      expect(registration.registered, ['token-1']);
      expect(platform.topics, ['zona-$_zone']);
      platform.currentToken = 'token-2';
      platform.tokens.add('token-2');
      await service.refresh();
      expect(registration.registered, ['token-1', 'token-2']);
      expect(registration.removed, ['token-1']);
      await service.updateSession(
        const PushCredentials(userId: 'ana', zoneId: 'otra-zona', accessToken: 'nuevo-jwt'),
      );
      expect(platform.removed, contains('zona-$_zone'));
      expect(platform.topics.last, 'zona-otra-zona');
      await service.signOut();
      expect(platform.deleted, 1);
      expect(registration.removed, contains('token-2'));
      expect(statuses.last, PushStatus.waitingForSession);
    });

    test('permiso denegado no registra ni suscribe', () async {
      platform.allowed = PushPermission.denied;
      await service.start(_credentials);
      expect(statuses.last, PushStatus.denied);
      expect(registration.registered, isEmpty);
      expect(platform.topics, isEmpty);
    });

    test('espera la sesión y conserva el destino de un inicio por aviso', () async {
      platform.initial = _message;
      await service.start(null);
      expect(routes, isEmpty);
      expect(registration.registered, isEmpty);
      await service.updateSession(_credentials);
      expect(routes, ['/publicaciones/$_post']);
      platform.opened.add(_message);
      expect(routes.length, 2);
    });

    test('sin red queda pendiente y al reintentar se recupera', () async {
      registration.connected = false;
      await service.start(_credentials);
      expect(statuses.last, PushStatus.pending);
      registration.connected = true;
      await service.refresh();
      expect(statuses.last, PushStatus.ready);
      expect(registration.registered, ['token-1']);
    });

    test('un inicio sin sesión invalida la instalación del usuario anterior', () async {
      await store.write(
        'push.installation',
        jsonEncode({'owner': 'anterior', 'token': 'viejo', 'topic': 'zona-anterior'}),
      );
      await service.start(null);
      expect(platform.deleted, 1);
      expect(platform.removed, ['zona-anterior']);
      expect(registration.registered, isEmpty);
    });
  });

  test('la API persiste pendientes y reutiliza la clave aun tras reiniciar', () async {
    final store = InMemorySecureStore();
    final requests = <RequestOptions>[];
    var connected = false;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (!connected) {
              handler.reject(
                DioException(requestOptions: options, type: DioExceptionType.connectionError),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: options.path.endsWith('baja') ? 204 : 200,
                ),
              );
            }
          },
        ),
      );
    var api = ApiPushRegistration(dio: dio, store: store, credentials: _credentials);
    expect(await api.register('token', 'android'), false);
    final key = requests.single.headers['Idempotency-Key'];
    api = ApiPushRegistration(dio: dio, store: store, credentials: _credentials);
    connected = true;
    expect(await api.retry(), true);
    expect(requests.last.headers['Idempotency-Key'], key);
    expect(requests.last.headers['Authorization'], 'Bearer jwt-de-prueba');
    expect(await api.unregister('token'), true);
    expect(requests.last.path, '/v1/dispositivos/baja');
    expect(await store.read('push.pending.ana'), isNull);
    dio.close();
  });

  testWidgets('un permiso denegado explica cómo activarlo y deja usar la app', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pushControllerProvider.overrideWith(_FixedStatus.new)],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PushSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Puedes seguir usando Vecinal'), findsOneWidget);
    expect(find.text('Comprobar de nuevo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final available in [true, false]) {
    testWidgets('el detalle lee la publicación local: disponible=$available', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PostDetailPage(
              postId: available ? _post : '01970000-0000-7000-8000-000000000000',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          available
              ? 'Presto taladro por la tarde'
              : 'Esta publicación todavía no está disponible en tu celular. Comprueba la conexión y vuelve a intentarlo.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
