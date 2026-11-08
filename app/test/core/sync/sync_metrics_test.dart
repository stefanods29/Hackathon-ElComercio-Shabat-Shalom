import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/sync/sync_metrics.dart';

final start = DateTime.utc(2026, 11, 7, 9);
final end = DateTime.utc(2026, 11, 8, 9);

Map<String, Object?> submission(
  String status, {
  required DateTime created,
  required DateTime answered,
  String? code,
}) => {
  'estado': status,
  'creado_en': created.toIso8601String(),
  'ultimo_intento_en': answered.toIso8601String(),
  'motivo_codigo': code,
};

SyncTelemetryReport report(
  Iterable<Map<String, Object?>> submissions, {
  int pendingUploads = 0,
  DateTime? lastSyncedAt,
  int connectionErrors = 0,
}) => buildSyncTelemetryReport(
  submissions: submissions,
  periodStart: start,
  periodEnd: end,
  pendingUploads: pendingUploads,
  lastSyncedAt: lastSyncedAt,
  connectionErrors: connectionErrors,
  appVersion: '0.1.0+1',
  system: 'android',
);

void main() {
  test('tres acciones enviadas a los 10, 20 y 90 segundos dan p50 de 20 y p95 de 90', () {
    expect(nearestRankPercentile([10, 20, 90], 50), 20);
    expect(nearestRankPercentile([90, 10, 20], 95), 90);
    final created = DateTime.utc(2026, 11, 7, 12);
    final counters = report([
      for (final seconds in [10, 20, 90])
        submission(
          'sent',
          created: created,
          answered: created.add(Duration(seconds: seconds)),
        ),
    ]);
    expect(counters.confirmedSends, 3);
    expect(counters.sentP50Seconds, 20);
    expect(counters.sentP95Seconds, 90);
  });

  test('el percentil usa rangos enteros y no depende del redondeo', () {
    final twenty = List.generate(20, (index) => index + 1);
    expect(nearestRankPercentile(twenty, 95), 19);
    expect(nearestRankPercentile(twenty, 50), 10);
    expect(nearestRankPercentile([7], 95), 7);
    expect(nearestRankPercentile(<int>[], 50), isNull);
  });

  test('cuenta solo lo que recibió su respuesta dentro del período', () {
    final before = start.subtract(const Duration(minutes: 1));
    final counters = report([
      submission('sent', created: before, answered: before),
      submission('sent', created: before, answered: start),
      submission('sent', created: before, answered: end.add(const Duration(seconds: 1))),
      submission('savedOnPhone', created: start, answered: end),
      submission('sent', created: start, answered: end),
    ]);
    expect(counters.confirmedSends, 1);
    expect(counters.sentP50Seconds, end.difference(start).inSeconds);
  });

  test('agrupa los rechazos permanentes por código del contrato', () {
    final at = start.add(const Duration(hours: 1));
    final counters = report([
      submission('couldNotComplete', created: at, answered: at, code: 'resena_duplicada'),
      submission('couldNotComplete', created: at, answered: at, code: 'resena_duplicada'),
      submission('couldNotComplete', created: at, answered: at, code: 'Conflicto-De Versión'),
      submission('couldNotComplete', created: at, answered: at),
    ]);
    expect(counters.permanentRejections, {
      'resena_duplicada': 2,
      'conflicto_de_versi_n': 1,
      'sin_codigo': 1,
    });
    expect(counters.confirmedSends, 0);
    expect(counters.sentP50Seconds, isNull);
    expect(counters.sentP95Seconds, isNull);
  });

  test('como máximo 20 códigos: el resto se suma en otros', () {
    final at = start.add(const Duration(hours: 1));
    final counters = report([
      for (var index = 0; index < 25; index++)
        for (var times = 0; times <= index; times++)
          submission('couldNotComplete', created: at, answered: at, code: 'codigo_$index'),
    ]);
    expect(counters.permanentRejections, hasLength(20));
    expect(counters.permanentRejections['codigo_24'], 25);
    expect(counters.permanentRejections.containsKey('codigo_0'), isFalse);
    // Codes 0 to 5 (1 + 2 + … + 6 = 21) go to `otros`.
    expect(counters.permanentRejections['otros'], 21);
  });

  test('el cuerpo trae solo los campos del contrato y sin datos del vecino', () {
    final body = report(
      [],
      pendingUploads: 2,
      lastSyncedAt: end.subtract(const Duration(seconds: 45)),
      connectionErrors: 3,
    ).toJson();
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
    expect(body['colaPendientes'], 2);
    expect(body['segundosDesdeUltimaSincronizacion'], 45);
    expect(body['erroresDeConexion'], 3);
    expect(body['periodoFin'], '2026-11-08T09:00:00.000Z');
  });

  test('sin sincronización previa el tiempo desde la última es nulo', () {
    expect(report([]).secondsSinceLastSync, isNull);
  });
}
