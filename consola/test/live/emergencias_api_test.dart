// Contrato de la consola con la API real de Emergencias (Fase 2, Lote C 2.5).
//
// Solo corre desde `npm run test:console-contract` en `backend/`, que levanta la API con datos
// ficticios y pasa sus datos en `VECINAL_API_FIXTURE`. Sin esa variable se salta.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/features/casos/data/http_cases_repository.dart';
import 'package:vecinal_consola/features/casos/domain/cases_repository.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';
import 'package:vecinal_consola/features/celdas/data/http_cells_repository.dart';
import 'package:vecinal_consola/features/turnos/data/http_shifts_repository.dart';
import 'package:vecinal_consola/features/turnos/domain/shifts.dart';

final _path = Platform.environment['VECINAL_API_FIXTURE'];

void main() {
  final skip = _path == null
      ? 'Sin VECINAL_API_FIXTURE: corre con npm run test:console-contract'
      : null;
  late Map<String, Object?> fixture;
  late String zone;
  late List<String> cases;
  late String brigadeId;
  late HttpCasesRepository casesA;
  late HttpCasesRepository casesB;
  late ConsoleApi apiA;

  ConsoleApi apiFor(Map<String, Object?> person) {
    final dio = Dio(
      BaseOptions(
        baseUrl: fixture['apiUrl']! as String,
        headers: {'authorization': 'Bearer ${person['token']}'},
      ),
    );
    return ConsoleApi(dio, onUnauthorized: () => fail('La API respondió 401.'));
  }

  Operator viewer(Map<String, Object?> person) => Operator(
    id: person['id']! as String,
    displayName: 'Coordinación ficticia',
    zoneId: zone,
    roles: const {OperationalRole.coordinator},
  );

  setUpAll(() {
    if (_path == null) return;
    fixture = jsonDecode(File(_path!).readAsStringSync()) as Map<String, Object?>;
    zone = fixture['zoneId']! as String;
    cases = (fixture['cases']! as List).cast<String>();
    brigadeId = fixture['brigadeId']! as String;
    final a = (fixture['coordinatorA']! as Map).cast<String, Object?>();
    final b = (fixture['coordinatorB']! as Map).cast<String, Object?>();
    apiA = apiFor(a);
    casesA = HttpCasesRepository(apiA, viewer(a));
    casesB = HttpCasesRepository(apiFor(b), viewer(b));
  });

  test('la cola trae los tres pedidos enviados, por prioridad y sin asignar', () async {
    final queue = sortQueue(await casesA.queue(zone));
    expect(queue.map((item) => item.id).toSet(), cases.toSet());
    expect(queue.map((item) => item.priority), [
      CasePriority.high,
      CasePriority.medium,
      CasePriority.low,
    ]);
    for (final item in queue) {
      expect(item.status, CaseStatus.sent);
      expect(item.need, EmergencyNeed.water);
      expect(item.unreviewedSince, isNotNull);
      expect(item.assignee, isNull);
      expect(item.exactLocation, isNull);
      expect(item.cellLabel, startsWith('Celda '));
    }
  }, skip: skip);

  test('las personas disponibles y las celdas salen de la API', () async {
    final people = await casesA.availablePeople(zone);
    expect(people.map((person) => person.id), contains(brigadeId));
    expect(
      people.singleWhere((person) => person.id == brigadeId).displayName,
      fixture['brigadeName'],
    );
    final snapshot = await HttpCellsRepository(apiA).cells(zone);
    final cell = snapshot.cells.single;
    expect(cell.byNeed[EmergencyNeed.water]?.value, 3);
    expect(cell.totalPublished, isFalse);
    expect(cell.countFor(null).value, 3);
  }, skip: skip);

  test('el detalle trae el historial y un cambio con versión vieja responde 409', () async {
    final detail = await casesA.detail(cases[0]);
    expect(detail.history.map((entry) => entry.to), [CaseStatus.sent]);
    expect(detail.history.single.role, 'vecino');
    expect(detail.exactLocation, isNull);
    await expectLater(
      casesA.apply(
        cases[0],
        seenVersion: detail.version + 5,
        command: const MarkSeen(),
        idempotencyKey: 'contrato-consola-1',
      ),
      throwsA(isA<ApiProblem>().having((p) => p.code, 'code', 'conflicto_de_version')),
    );
  }, skip: skip);

  test('la coordinadora asignada lo marca visto y asigna a la brigadista', () async {
    final seen = await casesA.apply(
      cases[0],
      seenVersion: (await casesA.detail(cases[0])).version,
      command: const MarkSeen(),
      idempotencyKey: 'contrato-consola-2',
    );
    expect(seen.status, CaseStatus.seen);
    final assigned = await casesA.apply(
      cases[0],
      seenVersion: seen.version,
      command: AssignCase(personId: brigadeId),
      idempotencyKey: 'contrato-consola-3',
    );
    expect(assigned.status, CaseStatus.seen);
    expect(assigned.assignee?.id, brigadeId);
    expect(assigned.assignee?.displayName, fixture['brigadeName']);
    expect(assigned.history.map((entry) => entry.to), [CaseStatus.sent, CaseStatus.seen]);
  }, skip: skip);

  test('otro coordinador toma el caso antes de cambiarlo', () async {
    final queue = await casesB.queue(zone);
    final item = queue.singleWhere((entry) => entry.id == cases[1]);
    final seen = await casesB.apply(
      cases[1],
      seenVersion: item.version,
      command: const MarkSeen(),
      idempotencyKey: 'contrato-consola-4',
    );
    expect(seen.status, CaseStatus.seen);
    // Now assigned to B, the audited detail opens for B.
    expect((await casesB.detail(cases[1])).status, CaseStatus.seen);
  }, skip: skip);

  test('derivar cierra el caso con su motivo y sale de la cola', () async {
    final item = (await casesA.queue(zone)).singleWhere((entry) => entry.id == cases[2]);
    final seen = await casesA.apply(
      cases[2],
      seenVersion: item.version,
      command: const MarkSeen(),
      idempotencyKey: 'contrato-consola-5',
    );
    final referred = await casesA.apply(
      cases[2],
      seenVersion: seen.version,
      command: const ReferCase(line: ReferralLine.firefighters, reason: 'Fuga de agua grave'),
      idempotencyKey: 'contrato-consola-6',
    );
    expect(referred.status, CaseStatus.referred);
    expect((await casesA.queue(zone)).map((entry) => entry.id), isNot(contains(cases[2])));
  }, skip: skip);

  test('el tablero de turnos crea y termina un turno de la brigadista', () async {
    final shifts = HttpShiftsRepository(apiA);
    final board = await shifts.board(zone);
    expect(
      board.operators.singleWhere((person) => person.id == brigadeId).role,
      OperationalRole.brigadist,
    );
    expect(coverageOf(board, DateTime.now()).covered, isTrue);
    final start = DateTime.now().add(const Duration(hours: 9));
    final created = await shifts.create(
      zone,
      ShiftDraft(personId: brigadeId, startsAt: start, endsAt: start.add(const Duration(hours: 6))),
      idempotencyKey: 'contrato-consola-7',
    );
    expect(created.role, OperationalRole.brigadist);
    expect(created.personName, fixture['brigadeName']);
    final ended = await shifts.end(created, idempotencyKey: 'contrato-consola-8');
    expect(ended.endedAt, isNotNull);
  }, skip: skip);
}
