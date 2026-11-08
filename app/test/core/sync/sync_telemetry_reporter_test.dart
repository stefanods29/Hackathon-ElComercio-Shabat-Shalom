import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/sync_telemetry_reporter.dart';

const account = '01970000-0000-7000-8000-0000000000b1';

class FakeSource implements SyncTelemetrySource {
  final rows = <Map<String, Object?>>[];
  final failures = StreamController<void>.broadcast();
  int pending = 0;

  @override
  Future<List<Map<String, Object?>>> submissionsAnsweredAfter(DateTime since) async => [
    for (final row in rows)
      if (DateTime.parse(row['ultimo_intento_en']! as String).isAfter(since)) row,
  ];

  @override
  Future<int> pendingUploads() async => pending;

  @override
  DateTime? lastSyncedAt;

  @override
  Stream<void> connectionFailures() => failures.stream;

  Future<void> close() => failures.close();
}

void main() {
  late FakeSource source;
  late InMemorySecureStore store;
  late Dio api;
  late List<RequestOptions> requests;
  late int status;
  late bool offline;
  late DateTime now;

  SyncTelemetryReporter reporter({String? system = 'android'}) => SyncTelemetryReporter(
    source: source,
    api: api,
    store: store,
    accountId: account,
    appVersion: '0.1.0+1',
    system: system,
    clock: () => now,
  );

  setUp(() {
    source = FakeSource();
    store = InMemorySecureStore();
    requests = [];
    status = 202;
    offline = false;
    now = DateTime.utc(2026, 11, 7, 9);
    api = Dio(BaseOptions(baseUrl: 'https://api.example.test', validateStatus: (_) => true));
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          if (offline) {
            handler.reject(
              DioException(requestOptions: request, type: DioExceptionType.connectionError),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: status,
              data: status == 202
                  ? {'recibidoEl': '2026-11-08'}
                  : {'status': status, 'title': 'Error', 'codigo': 'validacion'},
            ),
          );
        },
      ),
    );
  });
  tearDown(() async {
    await source.close();
    api.close(force: true);
  });

  void sentAfter(DateTime created, int seconds) => source.rows.add({
    'estado': 'sent',
    'creado_en': created.toIso8601String(),
    'ultimo_intento_en': created.add(Duration(seconds: seconds)).toIso8601String(),
    'motivo_codigo': null,
  });

  test('el primer día solo abre el período y no envía nada', () async {
    final telemetry = reporter();
    await telemetry.start();
    now = now.add(const Duration(hours: 23));
    await telemetry.maybeReport();
    expect(requests, isEmpty);
    await telemetry.close();
  });

  test('pasado un día envía solo los campos del contrato y no repite ese día', () async {
    final telemetry = reporter();
    await telemetry.start();
    final created = now.add(const Duration(hours: 2));
    for (final seconds in [10, 20, 90]) {
      sentAfter(created, seconds);
    }
    source.pending = 1;
    source.lastSyncedAt = now.add(const Duration(hours: 24, minutes: 59));
    source.failures.add(null);
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(hours: 25));
    await telemetry.maybeReport();

    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/telemetria/sincronizacion');
    expect(request.headers['Idempotency-Key'], isA<String>());
    final body = request.data as Map<String, Object?>;
    expect(body.keys.toSet(), {
      'versionApp',
      'sistema',
      'periodoInicio',
      'periodoFin',
      'colaPendientes',
      'enviosConfirmados',
      'tiempoHastaEnviadoP50Segundos',
      'tiempoHastaEnviadoP95Segundos',
      'rechazosPermanentes',
      'segundosDesdeUltimaSincronizacion',
      'erroresDeConexion',
    });
    expect(body, containsPair('enviosConfirmados', 3));
    expect(body, containsPair('tiempoHastaEnviadoP50Segundos', 20));
    expect(body, containsPair('tiempoHastaEnviadoP95Segundos', 90));
    expect(body, containsPair('colaPendientes', 1));
    expect(body, containsPair('segundosDesdeUltimaSincronizacion', 60));
    expect(body, containsPair('erroresDeConexion', 1));
    expect(body.toString(), isNot(contains(account)));

    now = now.add(const Duration(hours: 12));
    await telemetry.maybeReport();
    expect(requests, hasLength(1));
    await telemetry.close();
  });

  test(
    'sin conexión guarda el reporte y lo reintenta con la misma clave y el mismo cuerpo',
    () async {
      final telemetry = reporter();
      await telemetry.start();
      now = now.add(const Duration(days: 1, minutes: 1));
      offline = true;
      await telemetry.maybeReport();
      now = now.add(const Duration(hours: 1));
      offline = false;
      await telemetry.maybeReport();

      expect(requests, hasLength(2));
      expect(requests[1].headers['Idempotency-Key'], requests[0].headers['Idempotency-Key']);
      expect(requests[1].data, requests[0].data);
      expect(await store.read(SyncTelemetryReporter.pendingReportKey(account)), isNull);
      await telemetry.close();
    },
  );

  test('un 401 deja el reporte pendiente y un 400 lo descarta', () async {
    final telemetry = reporter();
    await telemetry.start();
    now = now.add(const Duration(days: 1, minutes: 1));
    status = 401;
    await telemetry.maybeReport();
    expect(await store.read(SyncTelemetryReporter.pendingReportKey(account)), isNotNull);
    status = 400;
    await telemetry.maybeReport();
    expect(await store.read(SyncTelemetryReporter.pendingReportKey(account)), isNull);
    expect(requests, hasLength(2));
    await telemetry.close();
  });

  test('en otros sistemas no reporta nada', () async {
    final telemetry = reporter(system: null);
    await telemetry.start();
    now = now.add(const Duration(days: 3));
    await telemetry.maybeReport();
    expect(requests, isEmpty);
    expect(await store.read(SyncTelemetryReporter.periodStartKey(account)), isNull);
    await telemetry.close();
  });

  test('cerrar sesión o borrar la cuenta borra sus claves', () async {
    final telemetry = reporter();
    await telemetry.start();
    await telemetry.close();
    expect(await store.read(SyncTelemetryReporter.periodStartKey(account)), isNotNull);
    await SyncTelemetryReporter.discard(store: store, accountId: account);
    expect(await store.read(SyncTelemetryReporter.periodStartKey(account)), isNull);
    expect(await store.read(SyncTelemetryReporter.pendingReportKey(account)), isNull);
  });
}
