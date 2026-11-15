import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/data/operational_emergency_repository.dart';
import 'package:vecinal/features/emergencias/data/own_help_request_repository.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_dashboard_page.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_widgets.dart';
import 'package:vecinal/features/emergencias/presentation/help_request_pages.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Phase 2, Lot A 1.5 on a device: a help request written without signal in Lot D's screens,
/// with the account's encrypted database. The network is cut and restored at the HTTP layer; the
/// author's stream rows are written as PowerSync would write them (live PowerSync is task 2.x).
const _zone = '01970000-0000-7000-8000-000000000001';
const _event = '0192f461-18fd-7b77-8975-7debbaf14227';

/// Lot B's API. Offline, every call fails like a phone in airplane mode.
class _Api implements HttpClientAdapter {
  var offline = false;
  final sent = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException.connectionError(requestOptions: options, reason: 'modo avión');
    }
    sent.add(options);
    final body = switch ('${options.method} ${options.path}') {
      'GET /v1/zonas/$_zone/cobertura' => {
        'zonaId': _zone,
        'habilitada': true,
        'eventoId': _event,
        'modo': 'emergencia',
      },
      'POST /v1/pedidos-ayuda' => {
        'id': (jsonDecode(options.data as String) as Map)['id'],
        'estado': 'enviado',
        'version': 1,
      },
      _ => null,
    };
    return ResponseBody.fromString(
      jsonEncode(body ?? {'status': 404}),
      body == null ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('un pedido sin señal dice que nadie lo recibió y se concilia al volver la señal', (
    tester,
  ) async {
    final directory = await (await getTemporaryDirectory()).createTemp('vecinal-pedido-offline-');
    addTearDown(() => directory.delete(recursive: true));
    final local = await LocalSyncDatabase.open(
      path: path.join(directory.path, 'account.db'),
      store: InMemorySecureStore(),
      accountId: 'cuenta',
    );
    addTearDown(local.close);
    final api = _Api();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test', validateStatus: (_) => true))
      ..httpClientAdapter = api;
    const scope = EmergencyScope(accountId: 'cuenta', zoneId: _zone, practice: false);
    final repository = OperationalEmergencyRepository(
      scope: scope,
      local: local,
      requests: OwnHelpRequestRepository(local, subscribe: (_) async => () {}),
      board: null,
      api: dio,
      fallbackLocation: const GeoPoint(-12.085, -77.035),
    );
    final t = await AppLocalizations.delegate.load(const Locale('es'));

    // With signal the phone learns that the zone has coordination; then the signal goes.
    await repository.refreshCoverage();
    api.offline = true;

    final router = GoRouter(
      initialLocation: Routes.emergencyDashboard,
      routes: [
        GoRoute(path: Routes.emergencyDashboard, builder: (_, _) => const EmergencyDashboardPage()),
        GoRoute(path: Routes.emergencyNeeds, builder: (_, _) => const EmergencyNeedsPage()),
        GoRoute(
          path: Routes.emergencyRequestForm,
          builder: (_, state) =>
              HelpRequestFormPage(need: EmergencyNeed.values.byName(state.pathParameters['need']!)),
        ),
        GoRoute(
          path: Routes.emergencyRequest,
          builder: (_, state) => OwnHelpRequestPage(requestId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emergencyScopeProvider.overrideWithValue(scope),
          emergencyRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          theme: AccessibleTheme.light(),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Three taps: "Necesito ayuda", the need, "Enviar" (writing is not a tap).
    var taps = 0;
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      taps++;
      await tester.pumpAndSettle();
    }

    await tap(find.text(t.emergencyNeedHelp).first);
    await tap(find.text(needLabel(t, EmergencyNeed.water)));
    await tester.enterText(find.byType(TextFormField).first, 'Pedido ficticio sin señal');
    await tester.pumpAndSettle();
    await tap(find.text(t.emergencySend));
    expect(taps, 3);

    // Saved on the phone, never sent: nobody received it and the official alternatives show.
    expect(find.textContaining(t.emergencyRequestLocalHelp), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining(t.emergencyLifeRisk), 200);
    expect(find.textContaining(t.emergencyLifeRisk), findsWidgets);
    expect(api.sent.where((request) => request.method == 'POST'), isEmpty);
    final queued = (await local.database.getNextCrudTransaction())!.crud.single;
    final body = jsonDecode(queued.opData!['cuerpo'] as String) as Map<String, Object?>;
    expect(body['eventoId'], _event);
    final id = body['id']! as String;

    // Still without signal, the upload fails and the request stays in the encrypted queue.
    final connector = VecinalConnector(dio);
    await expectLater(connector.uploadData(local.database), throwsA(anything));
    expect((await local.database.getUploadQueueStats()).count, 1);

    // The signal comes back: the queue sends it once and the stream brings the referral.
    api.offline = false;
    await connector.uploadData(local.database);
    expect(
      api.sent.where((request) => request.method == 'POST' && request.path == '/v1/pedidos-ayuda'),
      hasLength(1),
    );
    const reason = 'Derivado al servicio oficial de la zona';
    final closedAt = DateTime.now().toUtc().toIso8601String();
    await local.database.writeTransaction((tx) async {
      await tx.execute('INSERT INTO ps_data__mis_pedidos_ayuda (id, data) VALUES (?, ?)', [
        id,
        jsonEncode({
          'estado': 'derivado',
          'necesidad': 'agua',
          'prioridad': 'media',
          'version': 3,
          'creado_en': closedAt,
          'cerrado_en': closedAt,
        }),
      ]);
      for (final (index, (from, to)) in [
        (null, 'enviado'),
        ('enviado', 'visto'),
        ('visto', 'derivado'),
      ].indexed) {
        await tx.execute('INSERT INTO ps_data__historial_mis_pedidos (id, data) VALUES (?, ?)', [
          '${index + 1}',
          jsonEncode({
            'pedido_id': id,
            'desde': from,
            'hasta': to,
            'rol': 'coordinador',
            'ocurrido_en': closedAt,
            'motivo': to == 'derivado' ? reason : null,
          }),
        ]);
      }
    });
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining(reason), 200);
    expect(find.textContaining(reason), findsWidgets);
    expect(find.textContaining(t.emergencyRequestReferred), findsWidgets);
    expect(find.textContaining(t.emergencyRequestLocalHelp), findsNothing);
  });

  testWidgets('la práctica queda aislada de la cuenta real', (tester) async {
    final directory = await (await getTemporaryDirectory()).createTemp('vecinal-practica-');
    addTearDown(() => directory.delete(recursive: true));
    final local = await LocalSyncDatabase.open(
      path: path.join(directory.path, 'account.db'),
      store: InMemorySecureStore(),
      accountId: 'cuenta',
    );
    addTearDown(local.close);
    final practice = PracticeEmergencyRepository(DateTime.now);
    addTearDown(practice.close);
    final saved = await practice.saveRequest(
      HelpRequestDraft(
        id: '01970000-0000-7000-8000-00000000b001',
        idempotencyKey: '01970000-0000-7000-8000-00000000b002',
        need: EmergencyNeed.food,
        description: 'Pedido de práctica',
        locationLabel: '',
        approximateLocation: const GeoPoint(-12.085, -77.035),
      ),
    );
    // A practice request never claims a server receipt and never reaches the account's queue.
    expect(saved.status, HelpRequestStatus.local);
    expect(saved.sentAt, isNull);
    expect((await local.database.getUploadQueueStats()).count, 0);
    expect(await local.database.getAll('SELECT * FROM envios'), isEmpty);
  });
}
