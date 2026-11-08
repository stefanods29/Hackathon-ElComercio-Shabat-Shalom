import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/emergencias/data/operational_emergency_repository.dart';
import 'package:vecinal/features/emergencias/data/own_help_request_repository.dart';
import 'package:vecinal/features/emergencias/data/powersync_emergency_board.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';

const _zone = '01970000-0000-7000-8000-000000000001';
const _event = '0192f461-18fd-7b77-8975-7debbaf14227';
const _scope = EmergencyScope(accountId: 'cuenta', zoneId: _zone, practice: false);

/// Lot B's answers, by method and path; it records every request.
class _FakeApi implements HttpClientAdapter {
  final answers = <String, (int, Object?)>{};
  final requests = <RequestOptions>[];
  var offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (offline) {
      throw DioException.connectionError(requestOptions: options, reason: 'sin señal');
    }
    final (status, body) = answers['${options.method} ${options.path}'] ?? (404, {});
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalSyncDatabase local;
  late _FakeApi fake;
  late DateTime now;
  late OperationalEmergencyRepository repository;

  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('operational-emergency-');
    addTearDown(() => directory.delete(recursive: true));
    local = await LocalSyncDatabase.open(
      path: path.join(directory.path, 'account.db'),
      store: InMemorySecureStore(),
      accountId: 'cuenta',
    );
    addTearDown(local.close);
    fake = _FakeApi()
      ..answers['GET /v1/zonas/$_zone/cobertura'] = (
        200,
        {'zonaId': _zone, 'habilitada': true, 'eventoId': _event, 'modo': 'emergencia'},
      );
    now = DateTime.utc(2026, 11, 8, 12);
    repository = OperationalEmergencyRepository(
      scope: _scope,
      local: local,
      // No PowerSync service in the test: the author's stream rows are written below.
      requests: OwnHelpRequestRepository(local, subscribe: (_) async => () {}),
      board: PowerSyncEmergencyBoard(local.database, zoneId: _zone),
      api: Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = fake,
      fallbackLocation: const GeoPoint(-12.085, -77.035),
      clock: () => now,
    );
  });

  HelpRequestDraft draft() => HelpRequestDraft(
    id: newLocalId(),
    idempotencyKey: newLocalId(),
    need: EmergencyNeed.water,
    description: 'Adulto mayor sin agua',
    locationLabel: 'Frente al parque',
    approximateLocation: const GeoPoint(-12.085, -77.035),
  );

  Future<EmergencySnapshot> snapshotWhere(bool Function(EmergencySnapshot) test) =>
      repository.watch().firstWhere(test).timeout(const Duration(seconds: 5));

  test(
    'sin la cobertura de B no guarda; con ella el pedido queda en la cola con su evento',
    () async {
      fake.offline = true;
      await repository.refreshCoverage();
      await expectLater(repository.saveRequest(draft()), throwsStateError);

      fake.offline = false;
      await repository.refreshCoverage();
      final covered = await snapshotWhere((s) => s.coverageVerified);
      expect(covered.activeEvent, isTrue);

      final request = draft();
      final saved = await repository.saveRequest(request);
      expect(saved.status, HelpRequestStatus.local);
      expect(saved.sentAt, isNull);
      final command = (await local.database.getNextCrudTransaction())!.crud.single;
      final body = jsonDecode(command.opData!['cuerpo'] as String) as Map<String, Object?>;
      expect(body['eventoId'], _event);
      expect(body['necesidad'], 'agua');
      expect(body['descripcion'], 'Adulto mayor sin agua\nReferencia: Frente al parque');
      expect(body['ubicacion'], {'lat': -12.085, 'lng': -77.035});
      expect(body['riesgoVital'], isFalse);

      final listed = await snapshotWhere((s) => s.requests.isNotEmpty);
      expect(listed.requests.single.id, request.id.toLowerCase());
      expect(listed.requests.single.status, HelpRequestStatus.local);
    },
  );

  test('sin señal conserva la última confirmación hasta que deja de ser reciente', () async {
    await repository.refreshCoverage();
    fake.offline = true;
    now = now.add(const Duration(hours: 2));
    await repository.refreshCoverage();
    final recent = await snapshotWhere((_) => true);
    expect(recent.updatedAt, DateTime.utc(2026, 11, 8, 12));
    expect(recent.coverageVerified, isTrue);
    await repository.saveRequest(draft());

    now = now.add(const Duration(hours: 11));
    final expired = await snapshotWhere((_) => true);
    expect(expired.updatedAt, recent.updatedAt);
    expect(expired.coverageVerified, isFalse);
    await expectLater(repository.saveRequest(draft()), throwsStateError);
  });

  test('el estado sale del stream del autor y solo en camino se confirma la atención', () async {
    await repository.refreshCoverage();
    final request = draft();
    await repository.saveRequest(request);
    final id = request.id.toLowerCase();
    await local.database.writeTransaction((tx) async {
      await tx.execute('INSERT INTO ps_data__mis_pedidos_ayuda (id, data) VALUES (?, ?)', [
        id,
        jsonEncode({
          'estado': 'en_camino',
          'necesidad': 'agua',
          'prioridad': 'media',
          'version': 4,
          'creado_en': '2026-11-08T12:00:00Z',
        }),
      ]);
      for (final (index, (from, to)) in [
        (null, 'enviado'),
        ('enviado', 'visto'),
        ('visto', 'en_camino'),
      ].indexed) {
        await tx.execute('INSERT INTO ps_data__historial_mis_pedidos (id, data) VALUES (?, ?)', [
          '${index + 1}',
          jsonEncode({
            'pedido_id': id,
            'desde': from,
            'hasta': to,
            'rol': 'coordinador',
            'ocurrido_en': '2026-11-08T12:0$index:00Z',
          }),
        ]);
      }
    });
    final onTheWay = await snapshotWhere(
      (s) => s.requests.isNotEmpty && s.requests.single.status == HelpRequestStatus.onTheWay,
    );
    final mine = onTheWay.requests.single;
    expect(mine.canConfirmAttendance, isTrue);
    expect(mine.history.map((entry) => entry.status), [
      HelpRequestStatus.local,
      HelpRequestStatus.sent,
      HelpRequestStatus.seen,
      HelpRequestStatus.onTheWay,
    ]);

    fake.answers['POST /v1/pedidos-ayuda/$id/estado'] = (200, {'id': id, 'estado': 'atendido'});
    await repository.confirmAttendance(id);
    final confirm = fake.requests.lastWhere((r) => r.method == 'POST');
    expect(confirm.data, {'versionVista': 4, 'estado': 'atendido'});
    expect(confirm.headers[idempotencyKeyHeader], isNotNull);
  });

  test(
    'el tablero conserva el umbral y la fecha de verificación del recurso sincronizado',
    () async {
      final verifiedAt = now.subtract(const Duration(minutes: 2));
      await local.database.execute(
        'INSERT INTO ps_data__recursos_publicos (id, data) VALUES (?, ?)',
        [
          'recurso-agua',
          jsonEncode({
            'zona_id': _zone,
            'tipo': 'agua',
            'cantidad': 12,
            'celda': 'celda-publica',
            'reportado_en': now.subtract(const Duration(minutes: 5)).toIso8601String(),
            'umbral_segundos': 300,
            'verificacion': 'verificado',
            'etiqueta_publica': 'Punto de agua de prueba',
            'fuente_url': 'https://example.test/agua',
            'oficial': 1,
            'verificado_en': verifiedAt.toIso8601String(),
          }),
        ],
      );

      final snapshot = await snapshotWhere((s) => s.resources.isNotEmpty);
      final resource = snapshot.resources.single;
      expect(resource.id, 'recurso-agua');
      expect(resource.staleAfter, const Duration(minutes: 5));
      expect(const ResourceFreshnessPolicy().isStale(resource, now), isTrue);
      expect(resource.source?.verifiedAt, verifiedAt);
      expect(resource.source?.official, isTrue);
    },
  );

  test('un recurso viaja con tipo, cantidad y punto; una oferta queda en el celular', () async {
    fake.answers['POST /v1/zonas/$_zone/recursos'] = (200, {});
    await repository.reportResource(
      ResourceReportDraft(
        id: newLocalId(),
        idempotencyKey: 'clave-recurso-1',
        kind: ResourceKind.water,
        description: '',
        quantity: 12,
        location: const GeoPoint(-12.085, -77.035),
      ),
    );
    final report = fake.requests.lastWhere((r) => r.method == 'POST');
    expect((report.data as Map)['tipo'], 'agua');
    expect((report.data as Map)['cantidad'], 12);
    expect(report.data, isNot(contains('descripcion')));
    await expectLater(
      repository.reportResource(
        ResourceReportDraft(
          id: newLocalId(),
          idempotencyKey: 'clave-recurso-2',
          kind: ResourceKind.other,
          description: 'Texto libre',
          quantity: 1,
          location: const GeoPoint(-12.085, -77.035),
        ),
      ),
      throwsStateError,
    );

    await repository.saveOffer(
      HelpOffer(
        id: newLocalId(),
        idempotencyKey: newLocalId(),
        description: 'Tengo agua',
        createdAt: now,
      ),
    );
    final offers = await snapshotWhere((s) => s.offers.isNotEmpty);
    expect(offers.offers.single.status.name, 'savedOnPhone');
  });
}
