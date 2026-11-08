import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/network/idempotency.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/features/casos/data/http_cases_repository.dart';
import 'package:vecinal_consola/features/casos/domain/cases_repository.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';
import 'package:vecinal_consola/features/celdas/data/http_cells_repository.dart';
import 'package:vecinal_consola/features/turnos/data/http_shifts_repository.dart';
import 'package:vecinal_consola/features/turnos/domain/shifts.dart';

const _zone = '01970000-0000-7000-8000-000000000001';
const _case = '01970000-0000-7000-8000-00000000c001';
const _me = '01970000-0000-7000-8000-0000000000c1';
const _other = '01970000-0000-7000-8000-0000000000c2';
const _brigade = '01970000-0000-7000-8000-0000000000b9';

const _viewer = Operator(
  id: _me,
  displayName: 'Coordinadora',
  zoneId: _zone,
  roles: {OperationalRole.coordinator},
);

/// Answers by method and path, and records every request the repositories make.
class _FakeApi implements HttpClientAdapter {
  final routes = <String, List<(int, Object?)>>{};
  final requests = <RequestOptions>[];

  void on(String method, String path, int status, Object? body) =>
      (routes['$method $path'] ??= []).add((status, body));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final queue = routes['${options.method} ${options.path}'];
    if (queue == null || queue.isEmpty) {
      return ResponseBody.fromString('{"status":404,"codigo":"no_encontrado"}', 404);
    }
    final (status, body) = queue.length == 1 ? queue.first : queue.removeAt(0);
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

Map<String, Object?> _request({
  String state = 'enviado',
  int version = 1,
  List<Map<String, Object?>>? assignments,
}) => {
  'id': _case,
  'eventoId': '01970000-0000-7000-8000-00000000e001',
  'zonaId': _zone,
  'necesidad': 'agua',
  'prioridad': 'alta',
  'estado': state,
  'version': version,
  'celda': '7791:10296',
  'creadoEn': '2026-11-08T10:00:00.000Z',
  'venceEn': '2026-11-09T10:00:00.000Z',
  'vistoEn': null,
  'escalarEn': null,
  'asignaciones': ?assignments,
};

void main() {
  late _FakeApi fake;
  late ConsoleApi api;
  setUp(() {
    fake = _FakeApi();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = fake;
    api = ConsoleApi(dio, onUnauthorized: () {});
  });

  group('HttpCasesRepository', () {
    test('lee la cola de todas las páginas sin datos privados y con nombres', () async {
      fake
        ..on('GET', '/v1/operacion/zonas/$_zone/personas', 200, {
          'elementos': [
            {'id': _brigade, 'nombre': 'Brigadista Rosa', 'rol': 'brigadista', 'activo': true},
          ],
        })
        ..on('GET', '/v1/operacion/zonas/$_zone/casos', 200, {
          'elementos': [
            _request(
              state: 'visto',
              version: 3,
              assignments: [
                {'usuarioId': _me, 'rol': 'coordinador', 'venceEn': '2026-11-09T10:00:00Z'},
                {'usuarioId': _brigade, 'rol': 'brigadista', 'venceEn': '2026-11-09T10:00:00Z'},
              ],
            ),
          ],
          'siguienteCursor': _case,
        })
        ..on('GET', '/v1/operacion/zonas/$_zone/casos', 200, {
          'elementos': <Object?>[],
          'siguienteCursor': null,
        });
      final cases = await HttpCasesRepository(api, _viewer).queue(_zone);
      expect(cases, hasLength(1));
      final item = cases.single;
      expect(item.status, CaseStatus.seen);
      expect(item.priority, CasePriority.high);
      expect(item.need, EmergencyNeed.water);
      expect(item.version, 3);
      expect(item.unreviewedSince, isNull);
      expect(item.assignee?.displayName, 'Brigadista Rosa');
      expect(item.exactLocation, isNull);
      final pages = fake.requests.where((r) => r.path.endsWith('/casos')).toList();
      expect(pages.last.queryParameters['cursor'], _case);
    });

    test(
      'el detalle trae historial y ubicación exacta; sin asignación queda lo de la cola',
      () async {
        fake.on('GET', '/v1/operacion/zonas/$_zone/casos', 200, {
          'elementos': [_request()],
          'siguienteCursor': null,
        });
        final repository = HttpCasesRepository(api, _viewer);
        await repository.queue(_zone);
        final fallback = await repository.detail(_case);
        expect(fallback.status, CaseStatus.sent);
        expect(fallback.unreviewedSince, DateTime.parse('2026-11-08T10:00:00.000Z'));

        fake.on('GET', '/v1/pedidos-ayuda/$_case', 200, {
          ..._request(state: 'en_camino', version: 4),
          'descripcion': 'Texto que la consola no muestra',
          'ubicacionExacta': {'lat': -12.085, 'lng': -77.035},
          'historial': [
            {
              'desde': null,
              'hasta': 'enviado',
              'rol': 'vecino',
              'ocurridoEn': '2026-11-08T10:00:00Z',
            },
            {
              'desde': 'visto',
              'hasta': 'en_camino',
              'rol': 'brigadista',
              'ocurridoEn': '2026-11-08T10:20:00Z',
              'motivo': null,
            },
          ],
        });
        final detail = await repository.detail(_case);
        expect(detail.status, CaseStatus.onTheWay);
        expect(detail.history.map((entry) => entry.to), [CaseStatus.sent, CaseStatus.onTheWay]);
        expect(detail.history.first.from, isNull);
        expect(detail.exactLocation?.lat, -12.085);
      },
    );

    test('quien no tiene el caso lo toma antes de cambiarlo, con una clave derivada', () async {
      fake
        ..on('GET', '/v1/operacion/zonas/$_zone/casos', 200, {
          'elementos': [
            _request(
              assignments: [
                {'usuarioId': _other, 'rol': 'coordinador', 'venceEn': '2026-11-09T10:00:00Z'},
              ],
            ),
          ],
          'siguienteCursor': null,
        })
        ..on('POST', '/v1/pedidos-ayuda/$_case/asignaciones', 200, _request(version: 2))
        ..on('POST', '/v1/pedidos-ayuda/$_case/estado', 200, _request(state: 'visto', version: 3))
        ..on('GET', '/v1/pedidos-ayuda/$_case', 200, {
          ..._request(state: 'visto', version: 3),
          'historial': <Object?>[],
        });
      final repository = HttpCasesRepository(api, _viewer);
      await repository.queue(_zone);
      final updated = await repository.apply(
        _case,
        seenVersion: 1,
        command: const MarkSeen(),
        idempotencyKey: 'clave-de-prueba-1',
      );
      expect(updated.status, CaseStatus.seen);
      final writes = fake.requests.where((r) => r.method == 'POST').toList();
      expect(writes.map((r) => r.path), [
        '/v1/pedidos-ayuda/$_case/asignaciones',
        '/v1/pedidos-ayuda/$_case/estado',
      ]);
      expect(writes.first.data, {'versionVista': 1, 'usuarioId': _me, 'rol': 'coordinador'});
      expect(writes.last.data, {'versionVista': 2, 'estado': 'visto'});
      expect(writes.last.headers[idempotencyKeyHeader], 'clave-de-prueba-1');
      expect(writes.first.headers[idempotencyKeyHeader], isNot('clave-de-prueba-1'));
    });

    test('derivar envía el motivo con la línea oficial y no relee un caso cerrado', () async {
      fake
        ..on('GET', '/v1/operacion/zonas/$_zone/casos', 200, {
          'elementos': [
            _request(
              state: 'visto',
              version: 2,
              assignments: [
                {'usuarioId': _me, 'rol': 'coordinador', 'venceEn': '2026-11-09T10:00:00Z'},
              ],
            ),
          ],
          'siguienteCursor': null,
        })
        ..on(
          'POST',
          '/v1/pedidos-ayuda/$_case/estado',
          200,
          _request(state: 'derivado', version: 3),
        );
      final repository = HttpCasesRepository(api, _viewer);
      await repository.queue(_zone);
      final closed = await repository.apply(
        _case,
        seenVersion: 2,
        command: const ReferCase(line: ReferralLine.firefighters, reason: 'Incendio cercano'),
        idempotencyKey: 'clave-de-prueba-2',
      );
      expect(closed.status, CaseStatus.referred);
      final write = fake.requests.singleWhere((r) => r.method == 'POST');
      expect(write.data, {
        'versionVista': 2,
        'estado': 'derivado',
        'motivo': 'Línea 116: Incendio cercano',
      });
      expect(fake.requests.where((r) => r.path == '/v1/pedidos-ayuda/$_case'), isEmpty);
    });

    test('un conflicto de versión llega como Problem Details', () async {
      fake
        ..on('GET', '/v1/operacion/zonas/$_zone/casos', 200, {
          'elementos': [
            _request(
              assignments: [
                {'usuarioId': _me, 'rol': 'coordinador', 'venceEn': '2026-11-09T10:00:00Z'},
              ],
            ),
          ],
          'siguienteCursor': null,
        })
        ..on('POST', '/v1/pedidos-ayuda/$_case/estado', 409, {
          'status': 409,
          'codigo': 'conflicto_de_version',
          'title': 'Otra persona cambió el pedido',
        });
      final repository = HttpCasesRepository(api, _viewer);
      await repository.queue(_zone);
      await expectLater(
        repository.apply(
          _case,
          seenVersion: 1,
          command: const MarkSeen(),
          idempotencyKey: 'clave-de-prueba-3',
        ),
        throwsA(isA<ApiProblem>().having((p) => p.code, 'code', 'conflicto_de_version')),
      );
    });
  });

  test('las celdas agrupan por límites, sin totales ni sumas', () async {
    final bounds = {'sur': -12.09, 'oeste': -77.04, 'norte': -12.08, 'este': -77.03};
    fake.on('GET', '/v1/zonas/$_zone/celdas', 200, {
      'elementos': [
        {
          'id': '$_zone:7791:10296:agua',
          'limites': bounds,
          'necesidad': 'agua',
          'cantidad': 5,
          'actualizadoEn': '2026-11-08T10:05:00Z',
        },
        {
          'id': '$_zone:7791:10296:albergue',
          'limites': bounds,
          'necesidad': 'albergue',
          'cantidad': 3,
          'actualizadoEn': '2026-11-08T10:05:00Z',
        },
      ],
      'actualizadoEn': '2026-11-08T10:05:00Z',
    });
    final snapshot = await HttpCellsRepository(api).cells(_zone);
    final cell = snapshot.cells.single;
    expect(cell.totalPublished, isFalse);
    expect(cell.countFor(EmergencyNeed.water).value, 5);
    expect(cell.countFor(EmergencyNeed.food).isBelowThreshold, isTrue);
    // "All needs" shows the busiest published need: 5, never the sum 8.
    expect(cell.countFor(null).value, 5);
  });

  test('los turnos usan el rol del tablero y un id fijo por intento', () async {
    fake
      ..on('GET', '/v1/operacion/zonas/$_zone/turnos', 200, {
        'operadores': [
          {'id': _brigade, 'nombre': 'Brigadista Rosa', 'rol': 'brigadista', 'activo': true},
        ],
        'turnos': <Object?>[],
        'actualizadoEn': '2026-11-08T10:00:00Z',
      })
      ..on('POST', '/v1/operacion/zonas/$_zone/turnos', 200, {
        'id': '01970000-0000-7000-8000-00000000d001',
        'usuarioId': _brigade,
        'zonaId': _zone,
        'rol': 'brigadista',
        'inicio': '2026-11-08T11:00:00Z',
        'fin': '2026-11-08T19:00:00Z',
        'finalizadoEn': null,
        'version': 1,
      });
    final repository = HttpShiftsRepository(api);
    final board = await repository.board(_zone);
    expect(board.operators.single.role, OperationalRole.brigadist);
    final draft = ShiftDraft(
      personId: _brigade,
      startsAt: DateTime.utc(2026, 11, 8, 11),
      endsAt: DateTime.utc(2026, 11, 8, 19),
    );
    final shift = await repository.create(_zone, draft, idempotencyKey: 'clave-turno-1');
    expect(shift.personName, 'Brigadista Rosa');
    final body = fake.requests.singleWhere((r) => r.method == 'POST').data as Map;
    expect(body['rol'], 'brigadista');
    expect(body['inicio'], '2026-11-08T11:00:00.000Z');
    await repository.create(_zone, draft, idempotencyKey: 'clave-turno-1');
    final ids = fake.requests.where((r) => r.method == 'POST').map((r) => (r.data as Map)['id']);
    expect(ids.toSet(), hasLength(1));
  });
}
